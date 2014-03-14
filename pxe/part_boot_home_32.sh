#!/bin/bash
parted -s /dev/sda mklabel msdos
parted -s -a optimal /dev/sda mkpart primary ext2 0 513
parted -s -a optimal /dev/sda mkpart primary ext2 514 14000 
parted -s -a optimal /dev/sda mkpart primary linux-swap 14001 15000
parted -s -a optimal /dev/sda mkpart extended 15001 100%
parted -s -a optimal /dev/sda mkpart logical ext2 15002 100%
mkswap /dev/sda3 
if [ $? -ne 0 ]
then
	echo -e "\n\e[5;33;40mProblem creating swap, y'all...\e[0m <ENTER>"
	read xU
else
	echo -e "\n\e[1;32;40mSwap created successfully.\e[0m <ENTER>"
	sleep 3
fi
