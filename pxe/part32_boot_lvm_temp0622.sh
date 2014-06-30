#!/bin/bash
RC=0
parted -s /dev/sda mklabel msdos || ((RC+=$?))
sleep 1
parted -s -a optimal /dev/sda mkpart primary ext2 1 256 || echo 'Problem('$?') creating /boot'
parted -s -a optimal /dev/sda mkpart primary ext2 256 1304 || echo 'Problem('$?') creating swap'
mkswap /dev/sda2
sleep 1
parted -s -a optimal /dev/sda mkpart extended 1304 100% || echo 'Problem('$?') creating extended'
sleep 1
parted -s -a optimal /dev/sda mkpart logical ext3 1305 100% || echo 'Problem('$?') creating lvm'
sleep 1
set 5 lvm on || ((RC+=$?))

if [ $RC -eq 0 ]
then
    echo -e "\n\t\e[1;32;47mPartitioning was successful\e[0m"
else
    echo -e "\n\t\e[5;31;47mPartitioning was NOT successful. Contact Staff.\e[0m"
fi
fdisk -l /dev/sda
sleep 3

