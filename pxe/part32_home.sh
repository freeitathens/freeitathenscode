#!/bin/bash
parted -s /dev/sda mklabel msdos
parted -s -a minimal /dev/sda mkpart primary ext3 1 10513
parted -s -a minimal /dev/sda mkpart primary linux-swap 10513 11538
parted -s -a minimal /dev/sda mkpart extended 11538 100%
parted -s -a minimal /dev/sda mkpart logical ext3 11540 100%
fdisk -l /dev/sda

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

