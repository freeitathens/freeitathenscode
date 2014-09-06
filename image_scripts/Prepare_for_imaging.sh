#!/bin/bash
if [ 0 -ne $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
    Pauze 'if any problems rerun with sudo or as root'
fi

# Establish base of version-controlled code tree.
sourcebase="${HOME}/freeitathenscode"

UserSet_sourcebase() {
    declare -a prompted_sourcebase_a
    echo 'Normally FreeIT Code is in '$sourcebase
    read -p 'Your Code Location? ' -a prompted_sourcebase_a
    hold_sourcebase=${prompted_sourcebase_a[@]}
    if [[ "$hold_sourcebase" =~ 'EXIT' ]]
    then
        exit 2
    fi

    hold_sourcebase=${prompted_sourcebase_a[0]}
    [[ -d $hold_sourcebase ]] || exit 13
    sourcebase=hold_sourcebase
}

[[ -d $sourcebase ]] || UserSet_sourcebase

# Make the version-controlled tree - sourcebase --
#  -- an unchangable value (-r)
#  -- let child processes inherit (-x)
declare -rx sourcebase

# Establish location of Common Functions within sourcebase
codebase=${sourcebase}'/image_scripts'
[[ -d $temp_codebase ]] || exit 14
declare -rx codebase
source ${codebase}/Common_functions || exit 15

declare -r HOLDIFS=$IFS
declare -x Runner_shell_hold=$-
declare -rx Messages_O=$(mktemp -t "Prep_log.XXXXX")
declare -rx Errors_O=$(mktemp -t "Prep_err.XXXXX")
declare -x aptcache_needs_update='Y'
declare -x refresh_git='Y'
refresh_updatedb='N'
refresh_svn='N'

FreeIT_image='FreeIT.png'
distro_name=''

sys_rpts_distro_name_Set() {

    sys_rpts_distro_name=$(lsb_release -a 2>/dev/null\
            |grep '^Distributor ID:'|cut -f2 -d:\
            |sed -e 's/^[ \t]*//'|tr -d '\n')

    if [ -n ${sys_rpts_distro_name} ]
    then
        Pauze "System reports distro as ${sys_rpts_distro_name}."
        return 0
    fi

    # Try other methods
    if [ "${SESSION}." == 'Lubuntu.' ]
    then
        sys_rpts_distro_name=$SESSION
        Pauze 'Using session name '$distro_name' as distribution.'
        return 0
    fi

    # Tell calling routing we can't system-set distro name.
    return 12
}

Confirm_distro_name_Set() {
    distro_name=$1
    [[ -z $distro_name ]] && return 40

    prettyprint 'n,1,32,40,M,n' "Evaluating your input: ${distro_name}"

    sys_rpts_distro_name_Set;RCxS=$?
    if [ $RCxS -gt 0 ]
    then
        Pauze 'Cant confirm your distro name '\
        $distro_name' against the system name(s)'
        return 2
    fi

    if [ "${distro_name}." == "${sys_rpts_distro_name}." ]
    then
        Pauze "System distro value (${sys_rpts_distro_name}) agrees with your input (${distro_name})."
        return 0
    fi

    Pauze 'System distro value ('\
        ${sys_rpts_distro_name}\
          '): mismatch (however slight) with input: ('\
        ${distro_name}').'
    return 3
}

while getopts 'jRuVGhd:i:' OPT
do
    case $OPT in
        j)
            Runner_shell_hold=${Runner_shell_hold}'i'
            ;;
        d)
            Confirm_distro_name_Set $OPTARG;RCx1=$?
            [[ $RCx1 -gt 11 ]] && exit $RCx1
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
            echo $(basename $0)': Valid parms are -d Distro [-R|-u|-G|-i imagefile|-h|-j]'
            exit 0
        ;;
        *)
            Pauze "Unknown option: ${OPT}. Try: -d distro [ -R -u -G -i imagefile|-h|-j]"
            exit 8
            ;;
    esac
done

declare -rx Runner_shell_as=${Runner_shell_hold}
[[ "${refresh_updatedb}." == 'Y.' ]] && updatedb &

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

address_len=0
Get_Address_Len

distro_name_Set() {

    Pauze 'No distro supplied in parms. (e.g., -d FRITAROX)...'
    sys_rpts_distro_name_Set;RCxS=$?
    [[ $RCxS -eq 0 ]] || return 30

    Answer='N'
    Pause_n_Answer 'Y|N' '...system value '${distro_name}' is used, OK? '
    [[ "${Answer}." == 'Y.' ]] || return 12

    distro_name=$sys_rpts_distro_name

    return 0
}

if [[ -z $distro_name ]]
then 
    distro_name_Set;RCxD=$?
    if [ $RCxD -ne 0 ]
    then
        prettyprint '1,31,40,M,n' 'Cannot Set Distro name'
        Pauze 'Exiting....'
        exit $RCxD
    fi
fi

# *--* Confirm Distro name with user *--*
Confirm_DISTRO_CPU() {

    distro_valid_flag='?'
    prettyprint '1,32,40,M,0' $distro_name' is'
    case $distro_name in
    LinuxMint|mint)
        distro_generia='mint'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' ' a valid'
        ;;
    lubuntu|Ubuntu)
        distro_generia='ubuntu'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' ' a valid'
        ;;
    redhat|slackware|SuSE|crunchbang)
        distro_generia='other'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' " a valid (but you're on your own...)"
        ;;
    *)
        distro_generia='LINUX_DISTRO_not_appearing_in_this_film_WARE'
        distro_valid_flag='N'
        prettyprint '1,31,40,M' ' an INVALID'
        ;;
    esac
    prettyprint '1,32,40,M,n' ' distribution name.'
    [[ $distro_valid_flag != 'Y' ]] && return 16

    prettyprint '0,1,32,40,M,n' 'Using general distro (category) name of '$distro_generia'.'
    Pauze "INFO,Confirmed $distro_name on ${address_len}-bit box."

    return 0

}

Confirm_DISTRO_CPU;RCxDC=$?
if [ $RCxDC -gt 0 ]
then
    prettyprint '5,31,47,M,n,0' 'Exiting'
    Pauze "See you back soon!"
    exit $RCxDC
fi

Pauze 'Check (absence of) local UUID reference for swap in fstab.'
RCxU=1
grep -P 'UUID.+swap' /etc/fstab && RCxU=$?
if [ $RCxU -eq 0 ]
then
    Pauze 'fstab cAnNoT gO oN iMaGe wItH lOcAl UUID reference. Entering editor...'
    sudo vi /etc/fstab
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
        Pauze 'Check on subversion local repo status'
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

if [ $address_len -eq 32 ]
then
    Answer='N'
    Pause_n_Answer 'Y|N' 'WARN,Install oem-config packages (Default '$Answer')?'
    if [ "${Answer}." == 'Y.' ]
    then
    PK_OEM='oem-config oem-config-gtk oem-config-debconf ubiquity-frontend-[dgk].*'
    apt-get install $PK_OEM
    fi
fi

set -u

Pauze 'Try to set Frita Backgrounds'
backmess='Background Set?'
case $distro_generia in
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

case $distro_generia in
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
    if [ $distro_generia == 'mint' ]
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

case $distro_generia in
    lubuntu|ubuntu|mint)
        Pauze 'Run BPR Code'
        [[ -f ${codebase}/BPR_custom_prep.sh ]] &&\
            ${codebase}/BPR_custom_prep.sh
        Pauze "Run BPR: Last return code: $?"
        ;;
    *)
        Pauze "Don't need to run BPR additions for "$distro_generia' ('$distro_name')'
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

Mark_nouser_nogroup_fix_run="${HOME}/Ran_nouser_nogroup_fix"
if [ ! -e $Mark_nouser_nogroup_fix_run ]
then
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -uid 1000\
    -nouser -exec chown -c root {} \; & PIDnu=$!
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -gid 1000\
    -nogroup -exec chgrp -c root {} \; & PIDng=$!
    (while [ ! -e $Mark_nouser_nogroup_fix_run ];do sleep 30;ps -ef |awk '{print $2}' |egrep "$PIDnu|$PIDng" >/dev/null||touch $Mark_nouser_nogroup_fix_run;done;chmod -c 600 $Mark_nouser_nogroup_fix_run || logger -t 'Prepare2Image' 'Problem concluding Nouser Nogroup fix') &
fi

#Answer='Y'
#Pause_n_Answer 'Y|N' 'INFO,Check (absence of) local UUID reference for swap in fstab.(Default '$Answer')?'
#if [ "${Answer}." == 'Y.' ]
    #egrep -v '^\s*(#|$)' /etc/fstab\
