#!/bin/bash
parted -s /dev/sda mklabel msdos
parted -s -a optimal /dev/sda mkpart primary linux-swap 1MB 970MB 
parted -s -a optimal /dev/sda mkpart primary ext3 970MB 100%
mkswap /dev/sda1 
if [ $? -ne 0 ]
then
	echo -e "\n\e[1;33mProblem creating swap y'all\e[0m"
	read xU
fi
	
