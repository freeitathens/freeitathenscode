#!/bin/bash +x
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
    echo 'Hello User: Please rerun with sudo or root'
    exit 4
fi

source ${HOME}/freeitathenscode/image_scripts/Common_functions || exit 12

Distr0='bloatware'
refresh_from_apt='Y'
while getopts 'd:R' OPT
do
    case $OPT in
        d)
        Distr0=$OPTARG
        ;;
        R)
   	    refresh_from_apt='N'
        ;;
        *)
	    Pauze "Unknown option: $OPT . Try -d distro -R"
        ;;
    esac
done

Get_CPU_ADDRESS
Get_DISTRO $Distr0
Confirm_DISTRO_CPU || exit $?

egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID &&\
    prettyprint 'n,1,31,47,M,0,n'\
    'fstab cannot go on image with local UUID referencer'

Pauze 'Checking/Confirming removal of UUID reference in fstab' 'Launching apt upgrades(cond)'

if [ "${refresh_from_apt}." == 'Y.' ]
then
    apt-get update
    apt-get dist-upgrade
    apt-get autoremove
    apt-get clean
fi

find /root/.pulse /root/.dbus/session-bus -ls -delete
find /root/.pulse /root/.dbus/session-bus -ls
find /root/ -name ".pulse*" -ls -delete
find /root/ -name ".pulse*" -ls
find /home/oem/.ssh -not -type d -ls -delete
find /home/oem/.ssh -not -type d -ls

Pauze 'Cleaned up root files that oem used.' 'Clearing cups settings (if any)'

for CUPSDEF in /etc/cups/{classes,printers,subscriptions}.conf; do if [ -f ${CUPSDEF}.O ];then sudo cp -v ${CUPSDEF}.O $CUPSDEF;bn=$(basename $CUPSDEF);sudo find /etc/cups/ -name "${bn}*" -exec sudo md5sum {} \; -exec sudo ls -l {} \; ;else :;fi;done

Pauze 'Cleared cups settings' 'Removing QC Test Logs'

rm -v ${HOME}{,/Desktop}/QC*log

Pauze 'Removed QC Test Logs' 'Purge udev rules'

rm -v /etc/udev/rules.d/*

Pauze 'Purged udev rules' 'Checking swap area, memory available, and distro release'

swapon --summary --verbose
free
lsb_release -a

Pauze 'Checked swap area, memory available, and distro release' 'Remove Cache files'

#XFCE Only:
    #ensure existence of : /home/*/.config/xfce4/xfconf/
        #xfce-perchannel-xml/xfce4-session.xml: 
        #<property name="SessionName" type="string" value="Default"/>
for CD in $(find ${HOME}/ -depth -type d -not -empty -iname '*cache*'); do rm -rv ${CD}/*; done

#Bilt-images reminders (Cust_srt)
#- 32-bit
#  * Desktop Icon settings; remove File System (but useful on new-user?)

#/usr/share/lubuntu/wallpapers/: directory
#udevadm info --query=env --name=/dev/sda1 |grep UUID

