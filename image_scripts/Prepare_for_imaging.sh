#!/bin/bash +x
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
    echo 'Hello User: Please rerun with sudo or root'
    exit 4
fi

updatedb &

DISTRO=${1:-'unknown'}

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
# *--* Identify box as 32 or 64 bit capable. *--*
CPU_ADDRESS=32
CPUFLAGS=$(cat /proc/cpuinfo |grep '^flags')
for GL in $CPUFLAGS ;do if [ $GL == 'lm' ];then CPU_ADDRESS=64;fi;done
# if [ 64 -eq $(lscpu |grep '^Arch' |head -n1 |grep -o '64$' ]

# *--* Prepare for Distro-specific mods *--*
if [ $DISTRO == 'unknown' ]
then
    if [ "${SESSION}." == 'Lubuntu.' ]
    then
        DISTRO='lubuntu'
    elif [ $CPU_ADDRESS -eq 32 ]
    then
        DISTRO='lubuntu'
    fi
fi

# *--* Confirm Distro name with user *--*
echo "You're on a "$CPU_ADDRESS"-bit box running" $DISTRO'.'
case $DISTRO in
    lubuntu)
        echo -n 'Valid. <ENTER> to continue...'
        ;;
    mint)
        echo -n 'Valid. <ENTER> to continue...'
        ;;
    *)
        echo 'Invalid. Note, run this as' $0 'distroname'
    echo -e "\e[1;31;47mexiting\n\e[0m\n"
        ;;
esac
read Xu

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
Contact_server() {
    if [[ $(ssh -p8222 frita@192.168.1.9 'echo $HOSTNAME') =~ 'nuvo-servo' ]]
    then
        Pauze 'Server is valid <ENTER>'
    fi
}

Correct_subversion_ssh() {
    for LOC in ${HOME} /etc
    do
        SUBLOC="${LOC}/subversion"
        if [ -d ${SUBLOC} ]
        then 
            SUBCONF="${SUBLOC}/config"
            if [ -f ${SUBCONF} ]
            then
                echo "Fix $SUBCONF for Frita's ssh connection?..."
                read Xr
                case $Xr in
                Y|y)
                perl -pi'.bak' -e 's/#\s*ssh\s(.+?)ssh -q(.+)$/ssh ${1}ssh -p8222 -v${2}/' ${SUBCONF}
                ;;
                *)
                echo 'No changes made...'
                ;;
                esac
                break
            fi
        fi
    done
}

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
Pauze() {
    msg=$@
    echo -n $msg
    echo -e "\n\n\t\e[5;31;47mHit <Enter> to Continue\e[00m\n "
    read xR
}

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
# Remove reference to medibuntu (if any):
egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list

apt-get update || exit 4
apt-get install subversion || exit 6

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
Contact_server
if [ -d ${HOME}/freeitathenscode/.svn ]
then
    cd ${HOME}/freeitathenscode/
    svn update
else
    cd
    Correct_subversion_ssh
    svn co svn+ssh://frita@192.168.1.9/var/svn/Frita/freeitathenscode/
fi

PKGS='lm-sensors hddtemp ethtool gimp firefox dialog xscreensaver-gl libreoffice vlc aptitude vim flashplugin-installer'
apt-get install $PKGS

[[ -x /home/oem/freeitathenscode/image_scripts/image_update.sh ]] && /home/oem/freeitathenscode/image_scripts/image_update.sh

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
set -u

FreeIT_Background='FreeIT.png'
Backgrounds_location='/usr/share/backgrounds'
if [ $DISTRO == 'lubuntu' ]
then
    Backgrounds_location='/usr/share/lubuntu/wallpapers'
fi
Pauze 'Checking for' $FreeIT_Background 'background file'
Have_BG=$(ls -l ${Backgrounds_location}/$FreeIT_Background 2>/dev/null\
        || find ${Backgrounds_location}/ -name "$FreeIT_Background"\
        || echo 'NADA')
if [ "$Have_BG" == 'NADA' ]
then
    unset xR
    Pauze -n 'Shall I try to retrieve' $FreeIT_Background '(Y|N)?' 
    case $xR in
    y|Y)
    cp -iv /home/oem/freeitathenscode/image_scripts/$FreeIT_Background\
        ${Backgrounds_location}/ 2>/dev/null || exit 15
    ;;
    *) echo "OK, Handle it later... Movin' on...";sleep 2
    ;;
    esac
fi

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
# Notify if swap partition UUID is in /etc/fstab
egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID && echo -e "\n\e[1;31;47mfstab cannot go on image with local UUID reference\e[0m\n"
Pauze 'look for (absence of) local UUID reference for swap in fstab (above).'

#TODO ensure 'backports' in /etc/apt/sources.list

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

if [ $CPU_ADDRESS -eq 32 ]
then
    if [ $DISTRO == 'mint' ]
    # This is actually specific to xfce: mint (32?).
    then
        apt-get install gnome-system-tools 
        dpkg -l gnome-system-tools
        Pauze 'Have gnome-system-tools? <ENTER>'
    fi
else
    grep -o -P '^OnlyShowIn=.*MATE' /usr/share/applications/screensavers/*.desktop 
    Pauze 'Mate Desktop able to access xscreensavers for ant spotlight? <ENTER>'
fi

apt-get dist-upgrade
apt-get autoremove
aptitude autoclean

#Clean up root files that oem used.
find /root/.pulse /root/.dbus/session-bus -ls -delete
find /root/.pulse /root/.dbus/session-bus -ls
find /root/ -name ".pulse*" -ls -delete
find /root/ -name ".pulse*" -ls
find /home/oem/.ssh -not -type d -ls -delete
find /home/oem/.ssh -not -type d -ls

Pauze 'Clearing cups settings (if any)'
for CUPSDEF in /etc/cups/{classes,printers,subscriptions}.conf; do if [ -f ${CUPSDEF}.O ];then sudo cp -v ${CUPSDEF}.O $CUPSDEF;bn=$(basename $CUPSDEF);sudo find /etc/cups/ -name "${bn}*" -exec sudo md5sum {} \; -exec sudo ls -l {} \; ;else :;fi;done
#
Pauze "Removing QC test result files"
rm -vi ${HOME}{,/Desktop}/QC*log

# Additional options
#swapoff --all --verbose
swapon --summary --verbose
#udevadm info --query=env --name=/dev/sda1 |grep UUID
free
lsb_release -a
Pauze 'Free memory, swap, and version <ENTER>'
# *--------------------*
unset xR
echo 'Run nouser and nogroup checks/fixes? ("Y"; default is "n")'
read xR
if [ "${xR}." == 'Y.' ]
then
find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -uid 1000 -nouser -exec chown -c root {} \; &
find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -gid 1000 -nogroup -exec chgrp -c root {} \; &
fi

#XFCE Only:
    #ensure existence of : /home/*/.config/xfce4/xfconf/
        #xfce-perchannel-xml/xfce4-session.xml: 
        #<property name="SessionName" type="string" value="Default"/>
set +x

for CD in $(find ${HOME}/ -depth -type d -not -empty -iname '*cache*'); do rm -rv ${CD}/*; done

#/usr/share/lubuntu/wallpapers/: directory

