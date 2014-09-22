#!/bin/bash +x
declare -rx codebase="${HOME}/freeitathenscode"
source ${codebase}/image_scripts/Common_functions || exit 12

declare -r HOLDIFS=$IFS
declare -x Runner_shell_hold=$-
declare -rx Messages_O=$(mktemp -t "Prep2Clonze_log.XXXXX")
declare -rx Errors_O=$(mktemp -t "Prep2Clonze_err.XXXXX")
declare -x aptcache_needs_update='Y'

while getopts 'jd:Rh' OPT
do
    case $OPT in
        j)
            Runner_shell_hold=${Runner_shell_hold}'i'
	        ;;
        R)
            aptcache_needs_update='N'
            ;;
        h)
            Pauze $(basename $0) 'valid options are -d Distro -j [-R|-h]'
            exit 0
            ;;
        *)
            Pauze "Unknown option: $OPT"
            exit 8
            ;;
    esac
done
declare -rx Runner_shell_as=${Runner_shell_hold}

address_len=0
Get_Address_Len

Pauze 'Checking/Confirming removal of UUID reference in fstab'
egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID &&\
    prettyprint 'n,1,31,47,M,0,n'\
    'fstab cannot go on image with local UUID referencer'

Pauze "apt update ( COND: $aptcache_needs_update )"
if [ $aptcache_needs_update == 'Y' ]
then
    sudo apt-get update &>>${Messages_O} &
    Time_to_kill $! "Running apt-get update. Details in $Messages_O"
    export aptcache_needs_update='N'
fi
sudo apt-get dist-upgrade
sudo apt-get autoremove
sudo apt-get clean

Pauze 'Clearing out ssh secrets (and sort-of sec*)'
find /home/oem/.ssh -not -type d -ls -delete

Pauze 'Cleaning up root files that oem used...'
sudo find /root/.pulse /root/.dbus/session-bus -ls -delete
sudo find /root/ -name ".pulse*" -ls -delete

Pauze 'Removing QC Test Logs'
find ${HOME} -type f -name 'QC*log' -ok rm -v {} \;

Pauze 'Clearing cups local printer settings (if any)'
sudo find /etc/cups -type f -name 'printers.conf*' -ok sudo rm -v {} \;

Pauze 'Purge udev rules'
rm -v /etc/udev/rules.d/*

Pauze 'Checking swap area, memory available, and distro release'
swapon --summary --verbose
free
lsb_release -a

Pauze 'Remove Cache files'
select Cachedir in $(find ${HOME}/.cache -depth -mindepth 1 -type d -not -empty) 'RETURN'
do
    if [ $Cachedir == 'RETURN' ];then break;fi
    select Cachefile in $(find $Cachedir -type f) 'first10' 'first100' 'first1000' 'rEtUrN'
    do
        case $Cachefile in
	    rEtUrN) 
                break
            ;;
            first10)
                find $Cachedir -type f |head -n10 |xargs -r -I {} rm -v {}
            ;;
            first100)
                find $Cachedir -type f |head -n100 |xargs -r -I {} rm -v {}
            ;;
            first1000) 
                find $Cachedir -type f |head -n1000 |xargs -r -I {} rm -v {}
            ;;
            *) 
                rm -v $Cachefile
            ;;
        esac
    done
done

Pauze 'Extra effort to get all local files off'
cd || return 4
find . -maxdepth 1 -type f -ok rm -v {} \;
find .cache -type f -delete

find .config/chromium/ -type f -delete
find ./Desktop/ -type f -ok rm -v {} \;
find ./Documents/ -type f -delete
find ./Downloads/ -type f -delete
find .local/share/Trash/ -type f -delete
find ./.mozilla/firefox -type f -delete
find ./.ssh -type f -delete

Pauze 'Manually remove remaining oem-owned with rm -riv /var/lib/sudo/oem/*'

#find 
# -type f -delete
#find
#-type f -ok rm -v {} \;

#Bilt-images reminders (Cust_srt)
#- 32-bit
#  * Desktop Icon settings; remove File System (but useful on new-user?)

# XFCE Only:
#    ensure existence of : /home/*/.config/xfce4/xfconf/
#    xfce-perchannel-xml/xfce4-session.xml: 
#    <property name="SessionName" type="string" value="Default"/>

# udevadm info --query=env --name=/dev/sda1 |grep UUID

