#!/bin/bash +x
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
    echo 'Hello User: Please rerun with sudo or root'
    exit 4
fi

source /home/oem/freeitathenscode/image_scripts/Common_functions || exit 12
Get_CPU_ADDRESS
Get_DISTRO $1
Confirm_DISTRO_CPU || exit $?

egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID && echo -e "\n\e[1;31;47mfstab cannot go on image with local UUID reference\e[0m\n"
Pauze 'look for (absence of) local UUID reference for swap in fstab (above).'

# *-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-*
apt-get update
apt-get dist-upgrade
apt-get autoremove
apt-get clean

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
rm -v ${HOME}{,/Desktop}/QC*log
rm -v /etc/udev/rules.d/*

# Additional options
#swapoff --all --verbose
swapon --summary --verbose
#udevadm info --query=env --name=/dev/sda1 |grep UUID
free
lsb_release -a
Pauze 'Free memory, swap, and version <ENTER>'

#XFCE Only:
    #ensure existence of : /home/*/.config/xfce4/xfconf/
        #xfce-perchannel-xml/xfce4-session.xml: 
        #<property name="SessionName" type="string" value="Default"/>
for CD in $(find ${HOME}/ -depth -type d -not -empty -iname '*cache*'); do rm -rv ${CD}/*; done

#/usr/share/lubuntu/wallpapers/: directory



