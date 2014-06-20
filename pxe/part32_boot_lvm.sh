#!/bin/bash
RC=0
parted -s /dev/sda mklabel msdos || ((RC+=$?))
sleep 3
parted -s -a minimal /dev/sda mkpart primary ext2 1 512 || echo 'Problem('$?') creating /boot'
sleep 3
parted -s -a minimal /dev/sda mkpart primary ext2 512 2000 || echo 'Problem('$?') creating swap'
mkswap /dev/sda2 || echo 'Problem('$?') with mkswap'
parted -s -a minimal /dev/sda mkpart extended 2000 100% || echo 'Problem('$?') creating extended'
sleep 3
parted -s -a minimal /dev/sda mkpart logical ext3 2001 100% || echo 'Problem('$?') creating lvm'
sleep 3
set 5 lvm on || ((RC+=$?))

if [ $RC -eq 0 ]
then
    echo -e "\n\t\e[1;32;47mPartitioning was successful\e[0m"
else
    echo -e "\n\t\e[5;31;47mPartitioning was NOT successful. Contact Staff.\e[0m"
fi
fdisk -l /dev/sda
sleep 3

