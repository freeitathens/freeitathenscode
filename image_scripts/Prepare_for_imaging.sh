#!/bin/bash +x
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
	echo 'Hello User: Please rerun with sudo or root'
	exit 4
fi

# *------------------------------------------------------------------*
Pauze() {
    msg=$@
    echo -n $msg
#	[[ $msg =~ '<ENTER>' ]] || echo -n '<ENTER>'
    echo -e "\n\n\t\e[5;31;47mEnter to Continue\e[00m\n"
    read xR
}
Contact_server() {
    if [[ $(ssh -p8222 frita@192.168.1.9 'echo $HOSTNAME') =~ 'nuvo-servo' ]]
    then
	Pauze 'Server is valid <ENTER>'
	#scp -P8222 frita@192.168.1.9:~/freeitathenscode/image_scripts/FreeIT.png ~/
    fi
}

Contact_server

[[ -x /home/oem/freeitathenscode/image_scripts/image_update.sh ]] && /home/oem/freeitathenscode/image_scripts/image_update.sh

set -u

# " get FreeIT.png, move to common image dir ",
#sudo chown -c root:root FreeIT.png 
# *--* Identify box as 32 or 64 bit capable.

CPU_ADDRESS=32
CPUFLAGS=$(cat /proc/cpuinfo |grep '^flags')
for GL in $CPUFLAGS ;do if [ $GL == 'lm' ];then CPU_ADDRESS=64;fi;done
# if [ 64 -eq $(lscpu |grep '^Arch' |head -n1 |grep -o '64$' ]

Backgrounds_location='/usr/share/backgrounds'
if [ $CPU_ADDRESS -eq 32 ]
then
    Backgrounds_location='/usr/share/lubuntu/wallpapers'
fi
FreeIT_Background='FreeIT.png'
Pauze 'Checking for' $FreeIT_Background 'background file <ENTER>'
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

# "Remove reference to medibuntu":
egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list
egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID && echo -e "\n\e[1;31;47mfstab cannot go on image with local UUID reference\e[0m\n"
Pauze 'look for (absence of) local UUID reference for swap in fstab (above).'

#TODO ensure 'backports' in /etc/apt/sources.list

if [ 0 -eq $(find /etc/apt/sources.list.d/ -type f -name 'mozillateam*' |wc -l) ];then
	echo -n 'PPA: for firefox?'
	read Xr
	case $Xr in
	y|Y)
	sudo add-apt-repository ppa:mozillateam/firefox-next
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
	sudo add-apt-repository ppa:otto-kesselgulasch/gimp
	;;
	*)
	echo 'ok moving on...'
	;;
	esac
fi
for Pkg in lm-sensors hddtemp ethtool gimp firefox dialog xscreensaver-gl\
    chromium-browser libreoffice gnash vlc aptitude vim subversion
do
    sudo apt-get install $Pkg
done

if [ $CPU_ADDRESS -eq 32 ]
then
    sudo apt-get install gnome-system-tools 
    Pauze 'Have gnome-system-tools? <ENTER>'
else
    grep -o -P '^OnlyShowIn=.*MATE' /usr/share/applications/screensavers/*.desktop 
    Pauze 'Mate Desktop able to access xscreensavers for ant spotlight? <ENTER>'
    #TODO Might want to also remove mate-screensaver
fi

#Clean up root files that oem used.
sudo find /root/.pulse /root/.dbus/session-bus -ls -delete
sudo find /root/.pulse /root/.dbus/session-bus -ls
sudo find /root/ -name ".pulse*" -ls -delete
sudo find /root/ -name ".pulse*" -ls
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

sudo apt-get dist-upgrade
sudo apt-get autoremove
sudo aptitude autoclean
# *--------------------*
unset xR
echo 'Run nouser and nogroup checks/fixes? ("Y"; default is "n")'
read xR
if [ "${xR}." == 'Y.' ]
then
sudo find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -nouser -exec chown -c root {} \; &
sudo find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -nogroup -exec chgrp -c root {} \; &
fi

#XFCE Only:
    #ensure existence of : /home/*/.config/xfce4/xfconf/
        #xfce-perchannel-xml/xfce4-session.xml: 
        #<property name="SessionName" type="string" value="Default"/>
set +x

for CD in $(find ${HOME}/ -depth -type d -not -empty -iname '*cache*'); do rm -rv ${CD}/*; done

#/usr/share/lubuntu/wallpapers/: directory

