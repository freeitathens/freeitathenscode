#!/bin/bash
parted -s /dev/sda mklabel msdos
parted -s -a optimal /dev/sda unit s mkpart primary ext3 0% 19533823
parted -s -a optimal /dev/sda unit s mkpart primary linux-swap 19533824 21534719
parted -s -a optimal /dev/sda unit s mkpart extended 21536766 100%
parted -s -a optimal /dev/sda unit s mkpart logical ext3 21536768 100%

mkswap /dev/sda2 
if [ $? -ne 0 ]
then
	echo -e "\n\e[7;33;40mProblem creating swap, y'all...\e[1;31;40mNotify Frita Staff\e[0m"
	echo -n 'REBOOT (Control-Alt-Delete) | SHUTDOWN (Hold Power Button 4+ secs.) | <Enter> to continue '
	read xU
else
	echo -e "\n\e[1;32;40mSwap created successfully.\e[0m"
	sleep 2
fi
fdisk -l /dev/sda

