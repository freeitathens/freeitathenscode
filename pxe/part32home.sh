#!/bin/bash
parted -s /dev/sda mklabel msdos
parted -s -a optimal /dev/sda mkpart primary ext3 1 10000
parted -s -a optimal /dev/sda mkpart primary linux-swap 10001 11026
parted -s -a optimal /dev/sda mkpart extended 11027 100%
parted -s -a optimal /dev/sda mkpart logical ext3 11028 100%
mkswap /dev/sda2 
if [ $? -ne 0 ]
then
	echo -e "\n\e[5;33;40mProblem creating swap, y'all...\e[0m <ENTER>"
	read xU
else
	echo -e "\n\e[1;32;40mSwap created successfully.\e[0m <ENTER>"
	sleep 3
fi
