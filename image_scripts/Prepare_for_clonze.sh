#!/bin/bash +x

mr_man=$SUDO_USER
#[ -z "$mr_man" ] || exit 5
luser='oem'

declare -rx codebase="${HOME}/freeitathenscode"
source ${codebase}/image_scripts/Common_functions || exit 12

declare -r HOLDIFS=$IFS

Not_Batch_Run='N'

declare -rx Messages_O=$(mktemp -t "Prep2Clonze_log.XXXXX")
declare -rx Errors_O=$(mktemp -t "Prep2Clonze_err.XXXXX")
declare -x aptcache_needs_update='Y'

while getopts 'Bd:Rh' OPT
do
    case $OPT in
        B)
            Not_Batch_Run='Y'
	    ;;
        R)
            aptcache_needs_update='N'
            ;;
        h)
	    echo $(basename $0) 'valid options are -d Distro -j [-R|-h]'
            read -p'Mash <Enter> to EXIT' -t8
            exit 0
            ;;
        *)
	    echo 'Unknown option: '$OPT
            read -p'Mash <Enter> to EXIT' -t8
            exit 8
            ;;
    esac
done
declare -rx Not_Batch_Run

address_len=0
Get_Address_Len

read -p'Checking swap area, memory available, and distro release <Enter>' -t8
swapon --summary --verbose
free
lsb_release -a
echo -e "\n\n\n"

read -p 'Checking/Confirming removal of UUID reference in fstab <Enter>' -t8
egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID &&\
    prettyprint 'n,1,31,47,M,0,n'\
    'fstab cannot go on image with local UUID referencer'

echo 'apt update ( COND: '$aptcache_needs_update')'
read -p '<Enter>' -t8 -a Read_ARR
if [ $aptcache_needs_update == 'Y' ]
then
    sudo apt-get update &>>${Messages_O} &
    Time_to_kill $! "Running apt-get update. Details in $Messages_O"
    export aptcache_needs_update='N'
fi
sudo apt-get dist-upgrade
sudo apt-get autoremove
sudo apt-get clean
sudo apt-get autoclean

read -p'Clearing out ssh secrets (and sort-of sec*) <Enter>' -t8
find ${HOME}/.ssh -type f -ls -delete
find ${HOME}/.ssh -not -type d -ls -delete

read -p'Cleaning up root files that oem used...<Enter>' -t8
#sudo find /root/.pulse /root/.dbus/session-bus -ls -delete
#sudo find /root/ -name ".pulse*" -ls -delete
sudo find /root/.{pulse,cache,dbus,config}/ -depth ! -type d -ok rm -v {} \;

read -p'Removing QC Test Logs <Enter>' -t8
find ${HOME}/ -type f -name 'QC*log' -ok rm -v {} \;

read -p'Clearing cups local printer settings (if any) <Enter>' -t8
sudo find /etc/cups -type f -name 'printers.conf*' -ok sudo rm -v {} \;

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

read -p'Extra effort to get all local files off <Enter>' -t8
#find ${HOME}/ -maxdepth 1 -type f -ok rm -v {} \;
#find ${HOME}/Desktop/ -type f -ok rm -v {} \;
find ${HOME}/Documents/ -type f -delete
find ${HOME}/Downloads/ -type f -delete
find ${HOME}/.local/share/Trash/ -type f -delete

#read -p'Enter UID of QC user' -a ANS
#if [ ${#ANS[*]} -gt 0 ]
#then
#    userid=${ANS[0]}
#    echo 'Using UID of '$userid' as Quality Control User oem'
userid=$(grep "^$luser" /etc/passwd |cut -f3 -d:)
echo 'Userid is '$userid'. OK?'
read -p'<ENTER>'
sudo find /home/$luser -not -uid $userid -ok chown -c $luser {} \;
read -p'<ENTER>'

read -p'Manually remove remaining oem-owned with rm -riv /var/lib/sudo/oem/*'

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
#for TEMPFILE in $(find . -not -type d); do echo -n $TEMPFILE':';fuser -vu $TEMPFILE|| sudo rm -iv $TEMPFILE;echo ''; done
