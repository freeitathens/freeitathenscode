#!/bin/bash
parted -s /dev/sda mklabel msdos
parted -s -a optimal /dev/sda mkpart primary ext3 1 10001
parted -s -a optimal /dev/sda mkpart primary linux-swap 10001 12000
parted -s -a optimal /dev/sda mkpart extended 12000 100%
parted -s -a optimal /dev/sda mkpart logical ext3 12001 100%
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

