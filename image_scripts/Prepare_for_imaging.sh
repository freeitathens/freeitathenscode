#!/bin/bash
declare -rx codebase="${HOME}/freeitathenscode"
source ${codebase}/image_scripts/Common_functions || exit 12
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
    Pauze 'ERROR,Please rerun with sudo or as root'
    exit 4
fi

declare -r HOLDIFS=$IFS
declare -rx Messages_O=$(mktemp -t "Prep_log.XXXXX")
declare -rx Errors_O=$(mktemp -t "Prep_err.XXXXX")
declare -x aptcache_needs_update='Y'
declare -x refresh_git='Y'
fallback_distro=''
FreeIT_image='FreeIT.png'
refresh_update='N'

while getopts 'jd:i:RuGh' OPT
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
            refresh_update='Y'
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

if [ "${refresh_update}." == 'Y.' ]
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
    prettyprint '5,31,47,M,n,0' 'Exiting'
    Pauze "See you back soon!"
    exit $CDC_RC
fi

Pauze 'Check (absence of) local UUID reference for swap in fstab.'
egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID &&\
    prettyprint 'n,1,31,47,M,0,n'\
    'fstab cannot go on image with local UUID referencer'

Pauze 'Checking swap'
Run_Cap_Out swapoff --all --verbose
Run_Cap_Out swapon --all --verbose

Pauze 'Confirm no medibuntu in apt sources'
egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list

Pauze "apt update ( COND: $aptcache_needs_update )"
if [ $aptcache_needs_update == 'Y' ]
then
    apt-get update &>>${Messages_O} &
    Time_to_kill $! "Running apt-get update. Details in $Messages_O"
    export aptcache_needs_update='N'
fi
Pauze "install subversion"
apt-get install subversion || exit 6

Pauze "Check that server address is correct and is contactable ( COND: $refresh_update )"
if [ "${refresh_update}." == 'Y.' ]
then Contact_server
fi

Pauze 'Check on subversion status'
if [ -d ${codebase}/.svn ]
then
    cd ${codebase}/
    [[ "${refresh_update}." == 'Y.' ]] && svn update
else
    cd
    Correct_subversion_ssh
    svn co svn+ssh://frita@192.168.1.9/var/svn/Frita/freeitathenscode/
fi
cd

PKGS='lm-sensors hddtemp ethtool gimp firefox dialog xscreensaver-gl libreoffice aptitude vim flashplugin-installer htop inxi vrms oem-config oem-config-gtk oem-config-debconf ubiquity-frontend-[dgk].* mintdrivers'
Pauze 'Install necessary packages: ' $PKGS
apt-get install $PKGS

set -u

Pauze 'Try to set Frita Backgrounds'
backmess='Background Set?'
case $DISTRO in
    lubuntu|Ubuntu)
        Backgrounds_location='/usr/share/lubuntu/wallpapers'
        ;;
    *)
        Backgrounds_location='/usr/share/backgrounds'
        ;;
esac

Set_background $FreeIT_image;bg_RC=$?
case $bg_RC in
    0) backmess='Background setting ok'
    ;;
    5) backmess="Invalid backgrounds directory ${Backgrounds_location}. Set background manually"
    ;;
    6) backmess='Invalid background filename'
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
    lubuntu|Ubuntu|mint)
        Pauze 'Run BPR Code'
        [[ -f ${codebase}/image_scripts/BPR_custom_prep.sh ]] &&\
            ${codebase}/image_scripts/BPR_custom_prep.sh
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

Pauze 'Connecting Quality control stuff'
local_scripts_DIR="${HOME}/bin"
[[ -d $local_scripts_DIR ]] || mkdir $local_scripts_DIR
[[ -e ${local_scripts_DIR}/QC.sh ]] || ln -s ${codebase}/QC_Process/QC.sh ${local_scripts_DIR}/QC.sh

(find ${codebase}/QC_Process -iname 'Quality*' -exec md5sum {} \; ;\
    find ${codebase}/QC_process_dev/Master_${address_len} -iname 'Quality*' -exec md5sum {} \; ;\
    find ${HOME}/Desktop -iname 'Quality*' -exec md5sum {} \;) |grep -v '\.svn' |sort
#qc_desk="${codebase}/QC_Process/Quality\ Control.desktop"
#qc_dalt="${codebase}/QC_process_dev/MasterCPDRESS}/Quality\ Control.desktop"
#[[ -f "${qc_dalt}" ]] && qc_desk="$qc_dalt"
#qc_actu="${HOME}/Desktop/Quality\ Control.desktop"
#df_RC=0
#diff --brief "$qc_actu" "$qc_desk" || df_RC=$?
#if [ $df_RC -gt 0 ]
#then
#    Answer='N'
#    Pause_n_Answer 'Y|N' 'WARNING,Update Quality Control Desktop?'
#    if [ "${Answer}." == 'Y.' ]
#    then
#        cp -iv "$qc_desk" "$qc_actu"
#    fi
#fi

Answer='N'
Pause_n_Answer 'Y|N' 'INFO,Run nouser and nogroup checks/fixes?'
if [ "${Answer}." == 'Y.' ]
then
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -uid 1000 -nouser -exec chown -c root {} \; &
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -gid 1000 -nogroup -exec chgrp -c root {} \; &
fi

set +x

# *--* Confirm Distro name with user *--*
#Confirm_DISTPU() {
#    return_value=0
#
#    Pauze "WARN,You have a ${DDRESS}-bit box running $DISTRO ."

#    case $DISTRO in
#        lubuntu)
#            prettyprint '7,32,47,M,0' 'Valid'
#            ;;
#        LinuxMint|mint)
#            prettyprint '7,32,47,M,0' 'Valid'
#            DISTRO='mint'
#            ;;
#        Ubuntu)
#            prettyprint '7,32,47,M,0' 'Valid'
#            ;;
#        *)
#            prettyprint '1,31,47,M,0' 'Invalid:'
#            prettyprint 't,7,31,47,M,0,n' "Problem with Distro Name ${DISTRO}."
#            Pauze "PROBLEM,(Note, you can run this as $0 distroname)"
#            return 16
#            ;;
#    esac
#
#    Pauze "Confirmed Distro ${DISTRO}."
#    return $return_value
#}

