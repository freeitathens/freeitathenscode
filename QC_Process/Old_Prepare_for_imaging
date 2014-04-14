#!/bin/bash +x
set -u
# " get FreeIT.png, move to common image dir ",
#sudo chown -c root:root FreeIT.png 
# *--* Identify box as 32 or 64 bit capable.
CPU_ADDRESS=32
CPUFLAGS=$(cat /proc/cpuinfo |grep '^flags')
for GL in $CPUFLAGS ;do if [ $GL == 'lm' ];then CPU_ADDRESS=64;fi;done

# *------------------------------------------------------------------*
Pauze() {
    msg=$@
    echo -e "\n\n\t\e[5;31;47mThe Pause that Refreshes\e[00m\n"
    echo -n $msg
#	[[ $msg =~ '<ENTER>' ]] || echo -n '<ENTER>'
    read xR
}
Contact_server() {
    if [[ $(ssh -p8222 frita@192.168.1.9 'echo $HOSTNAME') =~ 'nuvo-servo' ]]
    then
	Pauze 'Server is valid <ENTER>'
	scp -P8222 frita@192.168.1.9:~/freeitathenscode/image_scripts/FreeIT.png ~/
    fi
}

FreeIT_Background='FreeIT.png'
#locate -i frita |grep -i 'frita.\+\.png'
#ls -l /usr/share/backgrounds/frita/FreeIT.png 
Pauze 'Checking for' $FreeIT_Background 'background file <ENTER>'
Have_BG=$(find /usr/share -name "$FreeIT_Background")
if [ -z "$Have_BG" ]
then
	unset xR
	Pauze -n 'Shall I try to retrieve' $FreeIT_Background '(Y|N)?' 
	case $xR in
	y|Y)
	Contact_server
	;;
	esac
fi

# "Remove reference to medibuntu":
egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list
egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID && echo -e "\n\e[1;31;47mfstab cannot go on image with local UUID reference\e[0m\n"
Pauze 'look for (absence of) local UUID reference for swap in fstab (above).'

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
    chromium-browser libreoffice gnash vlc aptitude vim
do
    sudo apt-get install $Pkg
done

if [ $CPU_ADDRESS -eq 32 ]
then
    sudo apt-get install gnome-system-tools 
else
    grep -o -P '^OnlyShowIn=.*MATE' /usr/share/applications/screensavers/*.desktop 
fi
Pauze 'CPU size specifice above <ENTER>'

#Clean up root files that oem used.
sudo find /root/.pulse /root/.dbus/session-bus -ls -delete
sudo find /root/.pulse /root/.dbus/session-bus -ls 2>/dev/null
sudo find /root/ -name ".pulse*" -ls -delete
sudo find /root/ -name ".pulse*" -ls 2>/dev/null
find ~/.ssh -not -type d -ls -delete
find ~/.ssh -not -type d -ls 2>/dev/null

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
Pauze 'Run nouser and nogroup checks/fixes? ("Y"; default is "n")'
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

