#!/bin/bash +x
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
    echo 'Hello User: Please rerun with sudo or root'
    exit 4
fi

updatedb &

source ${HOME}/freeitathenscode/image_scripts/Common_functions || exit 12
Get_CPU_ADDRESS
Get_DISTRO $1
Confirm_DISTRO_CPU || exit $?

FreeIT_image=${2:-'FreeIT.png'}

egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID && echo -e "\n\e[1;31;47mfstab cannot go on image with local UUID reference\e[0m\n"

Pauze '(absence of) local UUID reference for swap in fstab.' 'Checking swap'

swapoff --all --verbose
swapon --all --verbose

Pauze 'Checked swap' 'Confirm no medibuntu in apt sources'

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list

Pauze 'Confirmed no medibuntu in apt sources' 'apt update AND install subversion'

apt-get update || exit 4
apt-get install subversion || exit 6

Pauze 'apt update AND install subversion' 'Check that server address is correct and is contactable'

Contact_server

Pauze 'Checked that server address is correct and is contactable' 'Check on subversion status'

if [ -d ${HOME}/freeitathenscode/.svn ]
then
    cd ${HOME}/freeitathenscode/
    svn update
else
    cd
    Correct_subversion_ssh
    svn co svn+ssh://frita@192.168.1.9/var/svn/Frita/freeitathenscode/
fi

Pauze 'Checked on subversion status' 'install necessary packages'

PKGS='lm-sensors hddtemp ethtool gimp firefox dialog xscreensaver-gl libreoffice vlc aptitude vim flashplugin-installer htop'
apt-get install $PKGS

Pauze 'install necessary packages' 'Try to set Frita Backgrounds'

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
set -u

Backgrounds_location='/usr/share/backgrounds'
if [ $DISTRO == 'lubuntu' ]
then
    Backgrounds_location='/usr/share/lubuntu/wallpapers'
fi
Set_background $FreeIT_image;bg_RC=$?
case $bg_RC in
    0) echo 'background setting ok'
    ;;
    5) echo 'Invalid backgrounds directory' ${Backgrounds_location}'. Set background manually'
    ;;
    6) echo 'Invalid background filename'
    ;;
    *) echo 'Serious problems with setting background. RC='$bg_RC
    ;;
esac

Pauze 'Tried to set Frita Backgrounds' 'NOTE to ensure backports in list'

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
        source ${HOME}/freeitathenscode/image_scripts/BPR_xt_lubuntu_32bit.sh
fi

Pauze '(Lubuntu only) run Ben code' 'apt upgrade'

apt-get update
apt-get dist-upgrade

Pauze 'apt upgrade' 'No user / no group checks'

unset xR
echo 'Run nouser and nogroup checks/fixes? ("Y"; default is "n")'
read xR
if [ "${xR}." == 'Y.' ]
then
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -uid 1000 -nouser -exec chown -c root {} \; &
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -gid 1000 -nogroup -exec chgrp -c root {} \; &
fi

#Pauze '' ''
