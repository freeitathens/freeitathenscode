#!/bin/bash +x
declare -rx codebase="${HOME}/freeitathenscode"
source ${codebase}/image_scripts/Common_functions || exit 12
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
    Pauze 'ERROR,Please rerun with sudo or as root'
    exit 4
fi

declare -r HOLDIFS=$IFS
declare -x Runner_shell_hold=$-
declare -rx Messages_O=$(mktemp -t "Prep2Clonze_log.XXXXX")
declare -rx Errors_O=$(mktemp -t "Prep2Clonze_err.XXXXX")
declare -x aptcache_needs_update='Y'
fallback_distro=''

while getopts 'jd:Rh' OPT
do
    case $OPT in
        j)
            Runner_shell_hold=${Runner_shell_hold}'i'
	        ;;
        d)
            fallback_distro=$OPTARG
            ;;
        R)
            aptcache_needs_update='N'
            ;;
        h)
            Pauze $(basename $0) 'valid options are -d Distro [-R|-h|-j]'
            exit 0
            ;;
        *)
            Pauze "Unknown option: $OPT . Try -d distro [-R]"
            exit 8
            ;;
    esac
done
declare -rx Runner_shell_as=${Runner_shell_hold}

address_len=0
Get_Address_Len

DISTRO=$fallback_distro
Get_DISTRO $DISTRO;CDC_RC=$?
Confirm_DISTRO_CPU $CDC_RC;CDC_RC=$?
[[ $CDC_RC -gt 0 ]] && prettyprint '5,31,47,M,n,0' $DISTRO' Wha?'

Pauze 'Checking/Confirming removal of UUID reference in fstab'
egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID &&\
    prettyprint 'n,1,31,47,M,0,n'\
    'fstab cannot go on image with local UUID referencer'

Pauze 'Launching apt update (?COND='$aptcache_needs_update')'
if [ "${aptcache_needs_update}." == 'Y.' ]
then
    apt-get update
fi
apt-get dist-upgrade
apt-get autoremove
apt-get clean

Pauze 'Cleaning up root files that oem used...'
find /root/.pulse /root/.dbus/session-bus -ls -delete
find /root/.pulse /root/.dbus/session-bus -ls
find /root/ -name ".pulse*" -ls -delete
find /root/ -name ".pulse*" -ls
find ${HOME}/.ssh -not -type d -ls -delete
find ${HOME}/.ssh -not -type d -ls

Pauze 'Clearing cups settings (if any)'
for CUPSDEF in /etc/cups/{classes,printers,subscriptions}.conf; do if [ -f ${CUPSDEF}.O ];then sudo cp -v ${CUPSDEF}.O $CUPSDEF;bn=$(basename $CUPSDEF);sudo find /etc/cups/ -name "${bn}*" -exec sudo md5sum {} \; -exec sudo ls -l {} \; ;else :;fi;done

Pauze 'Removing QC Test Logs'
rm -v ${HOME}{,/Desktop}/QC*log

Pauze 'Purge udev rules'
rm -v /etc/udev/rules.d/*

Pauze 'Checking swap area, memory available, and distro release'
swapon --summary --verbose
free
lsb_release -a

Pauze 'Remove Cache files'
for CD in $(find ${HOME}/ -depth -type d -not -empty -iname '*cache*'); do rm -rv ${CD}/*; done

#Bilt-images reminders (Cust_srt)
#- 32-bit
#  * Desktop Icon settings; remove File System (but useful on new-user?)

# XFCE Only:
#    ensure existence of : /home/*/.config/xfce4/xfconf/
#    xfce-perchannel-xml/xfce4-session.xml: 
#    <property name="SessionName" type="string" value="Default"/>

# udevadm info --query=env --name=/dev/sda1 |grep UUID

