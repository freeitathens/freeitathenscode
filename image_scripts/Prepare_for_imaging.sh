#!/bin/bash
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
    echo 'ERROR, Please rerun with sudo or as root'
    exit 4
fi

# Establish root of version-controlled code tree.
temp_sourcebase="${HOME}/freeitathenscode"
if [ ! -d $temp_sourcebase ]
then
    read -p 'Location of Freeit code? ' -a temp_sourcebase
    if [ "${temp_sourcebase}." == 'N.' ]
    then
        exit 2
    fi
    [[ -d $temp_sourcebase ]] || exit 13
fi

# Make the version-controlled tree root - sourcebase - an unchangable value,
#   and let children inherit.
declare -rx sourcebase=$temp_sourcebase

# Establish directory of Common Functions within sourcebase (vc root)
temp_codebase=${sourcebase}'/image_scripts'
#echo 'Checking for existence of directory called '$temp_codebase
[[ -d $temp_codebase ]] || exit 14

declare -rx codebase=$temp_codebase
source ${codebase}/Common_functions || exit 15

declare -r HOLDIFS=$IFS
declare -rx Messages_O=$(mktemp -t "Prep_log.XXXXX")
declare -rx Errors_O=$(mktemp -t "Prep_err.XXXXX")
declare -x aptcache_needs_update='Y'
fallback_distro=''
FreeIT_image='FreeIT.png'
declare -x refresh_git='Y'
refresh_updatedb='N'
refresh_svn='N'

while getopts 'jd:i:RuVGh' OPT
do
    case $OPT in
        j)
            Runner_shell_hold=${Runner_shell_hold}'i'
        ;;
        d)
            fallback_distro=$OPTARG
            ;;
        i)
            FreeIT_image=$OPTARG
            ;;
        R)
            export aptcache_needs_update='N'
            ;;
        u)
            refresh_updatedb='Y'
            ;;
        V)
            refresh_svn='Y'
            ;;
        G)
            refresh_git='N'
            ;;
        h)
            Pauze $(basename $0) 'valid options are -d Distro [-R|-u|-G|-i imagefile|-h|-j]'
            exit 0
        ;;
        *)
            Pauze "Unknown option: ${OPT}. Try: -d distro [ -R -u -G -i imagefile|-h|-j]"
            exit 8
            ;;
    esac
done
declare -rx Runner_shell_as=${Runner_shell_hold}

Contact_server() {
    if [[ $(ssh -p8222 frita@192.168.1.9 'echo $HOSTNAME') =~ 'nuvo-servo' ]]
    then
        Pauze 'Checked Server is valid: 192.168.1.9'
        return 0
    fi
    return 1
}

Correct_subversion_ssh() {
    for subv_home in ${HOME}/.subversion /etc/subversion
    do
        [[ -d ${subv_home} ]] || return 8

        subv_conf="${subv_home}/config"
        if [ -f ${subv_conf} ]
        then
            Answer='N'
            Pause_n_Answer 'Y|N' "Fix $subv_conf for Frita's ssh connection (Y|N)? "
            case $Answer in
                Y)
                    sudo perl -pi'.bak' -e 's/#\s*ssh\b(.+?ssh)\s+-q(.+)$/ssh${1} -v${2}/' ${subv_conf}
                    [[ $? -eq 0 ]] && break
                    ;;
                *)
                    prettyprint 'n,t,34,47,M,0' 'No changes made...'
                    ;;
            esac
        fi
    done
    return 0

}

Set_background() {
    local Image_file=$1
    [[ -z "$Image_file" ]] && return 6
    local Image_dir=$2
    [[ -z "$Image_dir" ]] && return 9
    [[ -d "$Image_dir" ]] || return 5
    shift 2

    Pauze "Checking background file location: $Image_dir / $Image_file"
    Have_BG=$(ls -l ${Image_dir}/$Image_file)
    if [ $? -gt 0 ]
    then
        Pauze 'WARNING,OK, Background needs setup. First, searching all subdirs...'
        find ${Image_dir}/ -name "$Image_file" &
        Answer='Y'
        Pause_n_Answer 'Y|N' 'INFO,Shall I try to retrieve '$Image_file' (Default '$Answer')?'
        if [ "${Answer}." == 'Y.' ]
        then
            sudo cp -iv ${codebase}/$Image_file ${Image_dir}/ || return 15
        else
            Pauze 'WARNING,OK, Handle it later...'
        fi
    fi
}

if [ "${refresh_updatedb}." == 'Y.' ]
then
    updatedb &
fi

address_len=0
Get_Address_Len

DISTRO=$fallback_distro
Get_DISTRO $DISTRO;CDC_RC=$?
Confirm_DISTRO_CPU $CDC_RC;CDC_RC=$?
if [ $CDC_RC -gt 0 ]
then
    # prettyprint is sourced from Common_functions
    prettyprint '5,31,47,M,n,0' 'Exiting'
    Pauze "See you back soon!"
    exit $CDC_RC
fi

Answer='Y'
Pause_n_Answer 'Y|N' 'INFO,Check (absence of) local UUID reference for swap in fstab.(Default '$Answer')?'
if [ "${Answer}." == 'Y.' ]
then
    egrep -v '^\s*(#|$)' /etc/fstab\
        |grep swap |grep UUID && prettyprint 'n,1,31,47,M,0,n'\
        'fstab cannot go on image with local UUID reference'
fi

Pauze 'Checking swap'
Run_Cap_Out swapoff --all --verbose
Run_Cap_Out swapon --all --verbose

#Pauze 'Confirm no medibuntu in apt sources'
#egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list

Pauze "apt update ( COND: $aptcache_needs_update )"
if [ $aptcache_needs_update == 'Y' ]
then
    apt-get update &>>${Messages_O} &
    Time_to_kill $! "Running apt-get update. Details in $Messages_O"
    export aptcache_needs_update='N'
fi

Pauze "install subversion"
apt-get install subversion || exit 6

Pauze "Check that server address is correct and is contactable ( COND: $refresh_svn )"
if [ "${refresh_svn}." == 'Y.' ]
then
    Contact_server
    if [ $? -lt 1 ]
    then
        Pauze 'Check on subversion status'
        if [ -d ${sourcebase}/.svn ]
        then
            cd ${sourcebase}/
            svn update
        else
            cd
            Correct_subversion_ssh
            svn co svn+ssh://frita@192.168.1.9/var/svn/Frita/freeitathenscode/
        fi
        cd
    fi
fi

PKGS='lm-sensors hddtemp ethtool gimp firefox dialog xscreensaver-gl libreoffice aptitude vim flashplugin-installer htop inxi vrms mintdrivers gparted terminator hardinfo'
Pauze 'Install necessary packages: ' $PKGS
apt-get install $PKGS

Answer='N'
Pause_n_Answer 'Y|N' 'WARN,Install oem-config packages (Default '$Answer')?'
if [ "${Answer}." == 'Y.' ]
then
    PK_OEM='oem-config oem-config-gtk oem-config-debconf ubiquity-frontend-[dgk].*'
    apt-get install $PK_OEM
fi

set -u

Pauze 'Try to set Frita Backgrounds'
backmess='Background Set?'
case $DISTRO in
    lubuntu|ubuntu)
        Backgrounds_location='/usr/share/lubuntu/wallpapers'
        ;;
    *)
        Backgrounds_location='/usr/share/backgrounds'
        ;;
esac

Set_background $FreeIT_image $Backgrounds_location
bg_RC=$?
case $bg_RC in
    0) backmess='Background setting ok'
    ;;
    5) backmess="Invalid backgrounds directory ${Backgrounds_location}. Set background manually"
    ;;
    6) backmess='Invalid background filename '$FreeIT_image
    ;;
    *) backmess="Serious problems with setting background. RC=${bg_RC}"
    ;;
esac

Pauze "Response from setting Frita Backgrounds was $backmess"

case $DISTRO in
    mint)
        Pauze 'WARNING,Ensure backports in /etc/apt/sources.list (or sources.d/)' 
        ;;
    *)
        Pauze 'Assuming Backports are automatically included'
        ;;
esac

Pauze 'PPAs for firefox and gimp'
if [ 0 -eq $(find /etc/apt/sources.list.d/ -type f -name 'mozillateam*' |wc -l) ];then
    echo -n 'PPA: for firefox?'
    read Xr
    case $Xr in
    y|Y)
    add-apt-repository ppa:mozillateam/firefox-next
    ;;
    *)
    echo 'ok moving on...'
    ;;
    esac
fi
if [ 0 -eq $(find /etc/apt/sources.list.d/ -type f -name 'otto-kesselgulasch*' |wc -l) ];then
    echo -n 'PPA: for gimp?'
    read Xr
    case $Xr in
    y|Y)
    add-apt-repository ppa:otto-kesselgulasch/gimp
    ;;
    *)
    echo 'ok moving on...'
    ;;
    esac
fi

Pauze 'mint and mate specials'
if [ $address_len -eq 32 ]
then
    if [ $DISTRO == 'mint' ]
    # This is actually specific to xfce: mint (32?).
    then
        apt-get install gnome-system-tools 
        dpkg -l gnome-system-tools
        Pauze 'Have gnome-system-tools?'
    fi
else
    grep -o -P '^OnlyShowIn=.*MATE' /usr/share/applications/screensavers/*.desktop 
    Pauze 'Mate Desktop able to access xscreensavers for ant spotlight?'
fi

case $DISTRO in
    lubuntu|ubuntu|mint)
        Pauze 'Run BPR Code'
        [[ -f ${codebase}/BPR_custom_prep.sh ]] &&\
            ${codebase}/BPR_custom_prep.sh
        Pauze "Run BPR: Last return code: $?"
        ;;
    *)
        Pauze "Don't need to run BPR additions for "$DISTRO
        ;;
esac

Pauze 'apt-get update ( COND: '$aptcache_needs_update ')'
if [ $aptcache_needs_update == 'Y' ]
then
    apt-get update
    export aptcache_needs_update='N'
fi
Pauze 'apt dist-upgrade'
apt-get dist-upgrade

Pauze 'Lauching Virtual Greybeard'
vrms
Pauze '/\Please Purge Non-Free Stuff IF NEEDED/\'

Pauze "Ensuring that QC.sh and revert_prep... are properly linked in ${HOME}/bin" 
local_scripts_DIR="${HOME}/bin"
[[ -d $local_scripts_DIR ]] || mkdir $local_scripts_DIR
chown -c oem $local_scripts_DIR
[[ -e ${local_scripts_DIR}/QC.sh ]] || ln -s ${sourcebase}/QC_Process/QC.sh ${local_scripts_DIR}/QC.sh
[[ -e ${local_scripts_DIR}/revert_prep_for_shipping_to_eu ]]\
    || ln -s ${codebase}/revert_prep_for_shipping_to_eu ${local_scripts_DIR}/revert_prep_for_shipping_to_eu 

Pauze 'Confirming that the correct Run Quality Control icon is in place...'
(find ${sourcebase}/QC_Process -iname 'Quality*' -exec md5sum {} \; ;\
    find ${sourcebase}/QC_process_dev/Master_${address_len} -iname 'Quality*' -exec md5sum {} \; ;\
    find ${HOME}/Desktop -iname 'Quality*' -exec md5sum {} \;) |grep -v '\.svn' |sort

Answer='N'
Pause_n_Answer 'Y|N' 'INFO,Run nouser and nogroup checks/fixes?'
if [ "${Answer}." == 'Y.' ]
then
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -uid 1000 -nouser -exec chown -c root {} \; &
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -gid 1000 -nogroup -exec chgrp -c root {} \; &
fi

set +x

