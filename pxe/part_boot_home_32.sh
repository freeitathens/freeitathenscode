#!/bin/bash
parted -s /dev/sda mklabel msdos
parted -s -a optimal /dev/sda mkpart primary ext2 2 520
parted -s -a optimal /dev/sda mkpart primary ext3 521 15000 
parted -s -a optimal /dev/sda mkpart primary linux-swap 15001 16000
parted -s -a optimal /dev/sda mkpart extended 16001 100%
parted -s -a optimal /dev/sda mkpart logical ext3 16002 100%
mkswap /dev/sda3 
if [ $? -ne 0 ]
then
	echo -e "\n\e[5;33;40mProblem creating swap, y'all...\e[0m <ENTER>"
	read xU
else
	echo -e "\n\e[1;32;40mSwap created successfully.\e[0m <ENTER>"
	sleep 3
fi

