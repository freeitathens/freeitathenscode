#!/bin/bash +x
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
    echo 'Hello User: Please rerun with sudo or root'
    exit 4
fi

source ${HOME}/freeitathenscode/image_scripts/Common_functions || exit 12

Distr0='bloatware'
FreeIT_image='FreeIT.png'
refresh_from_apt='Y'
refresh_update='Y'
refresh_git='Y'

while getopts 'd:i:RUG' OPT
do
    case $OPT in
        d)
            Distr0=$OPTARG
            ;;
        i)
            FreeIT_image=$OPTARG
            ;;
        R)
            refresh_from_apt='N'
            ;;
        U)
            refresh_update='N'
            ;;
        G)
            refresh_git='N'
            ;;
        *)
            Pauze "Unknown option: ${OPT}. Try: -d distro [ -R -U -G -i imagefile]"
            ;;
    esac
done

if [ "${refresh_update}." == 'Y.' ]
then
    updatedb &
fi

Get_CPU_ADDRESS
Get_DISTRO $Distr0
Confirm_DISTRO_CPU || exit $?

egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID &&\
    prettyprint 'n,1,31,47,M,0,n'\
    'fstab cannot go on image with local UUID referencer'

Pauze '(absence of) local UUID reference for swap in fstab.' 'Checking swap'

swapoff --all --verbose
swapon --all --verbose

Pauze 'Checked swap' 'Confirm no medibuntu in apt sources'

egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list

Pauze 'Confirmed no medibuntu in apt sources' 'apt update AND install subversion'

if [ $refresh_from_apt == 'Y' ]
then
    apt-get update || exit 4
    apt-get install subversion || exit 6
fi

Pauze 'apt update AND install subversion' 'Check that server address is correct and is contactable (cond)'

if [ "${refresh_update}." == 'Y.' ]
then Contact_server
fi

Pauze 'Checked that server address is correct and is contactable' 'Check on subversion status'

if [ -d ${HOME}/freeitathenscode/.svn ]
then
    cd ${HOME}/freeitathenscode/
    [[ "${refresh_update}." == 'Y.' ]] && svn update
else
    cd
    Correct_subversion_ssh
    svn co svn+ssh://frita@192.168.1.9/var/svn/Frita/freeitathenscode/
fi
cd

Pauze 'Checked on subversion status' 'install necessary packages'

if [ $refresh_from_apt == 'Y' ]
then
    PKGS='lm-sensors hddtemp ethtool gimp firefox dialog xscreensaver-gl libreoffice vlc aptitude vim flashplugin-installer htop'
    apt-get install $PKGS
fi

Pauze 'install necessary packages' 'Try to set Frita Backgrounds'

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
set -u

Backgrounds_location='/usr/share/backgrounds'
if [ $DISTRO == 'lubuntu' ]
then
    Backgrounds_location='/usr/share/lubuntu/wallpapers'
fi
backmess='Background Set?'

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

Pauze 'Set Frita Backgrounds' 'NOTE to ensure backports in list' $backmess

#TODO ensure 'backports' in /etc/apt/sources.list

Pauze 'NOTE to ensure backports in list' 'PPAs for firefox and gimp'

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

Pauze 'PPAs for firefox and gimp' 'mint and mate specials'

if [ $CPU_ADDRESS -eq 32 ]
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

Pauze 'gnome-system tools or mate can use xscreensaver' '(Lubuntu only) Run Ben Code'

if [ $DISTRO == 'lubuntu' ]
then
    [[ -f ${HOME}/freeitathenscode/image_scripts/BPR_xt_lubuntu_32bit.sh ]] &&\
        ${HOME}/freeitathenscode/image_scripts/BPR_xt_lubuntu_32bit.sh $refresh_from_apt $refresh_git
fi

Pauze '(Lubuntu only) run Ben code' 'apt upgrade' 'Last return code:' $?

if [ $refresh_from_apt == 'Y' ]
then
    apt-get update
    apt-get dist-upgrade
fi

Pauze 'apt upgrade' 'No user / no group checks'

unset xR
echo 'Run nouser and nogroup checks/fixes? ("Y"; default is "n")'
read xR
if [ "${xR}." == 'Y.' ]
then
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -uid 1000 -nouser -exec chown -c root {} \; &
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -gid 1000 -nogroup -exec chgrp -c root {} \; &
fi

