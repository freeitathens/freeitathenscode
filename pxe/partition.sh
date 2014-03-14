#!/bin/bash
parted -s /dev/sda mklabel msdos
parted -s -a optimal /dev/sda mkpart primary linux-swap 1 1025 
parted -s -a optimal /dev/sda mkpart primary ext3 1025 100%
mkswap /dev/sda1 
if [ $? -ne 0 ]
then
	echo -e "\n\e[5;33;40mProblem creating swap, y'all...\e[0m <ENTER>"
	read xU
else
	echo -e "\n\e[1;32;40mSwap created successfully.\e[0m"
	sleep 3
fi
