#!/bin/bash
RC=0
parted -s /dev/sda mklabel msdos || ((RC+=$?))
sleep 3
parted -s -a cylinder /dev/sda mkpart primary ext2 1 512 || echo 'Problem('$?') creating /boot'
sleep 3
parted -s -a cylinder /dev/sda mkpart extended 512 100% || echo 'Problem('$?') creating extended'
sleep 3
parted -s -a cylinder /dev/sda mkpart logical ext3 513 100% || echo 'Problem('$?') creating lvm'
sleep 3
set 5 lvm on || ((RC+=$?))
/sbin/sfdisk --change-id /dev/sda 5 8e

if [ $RC -eq 0 ]
then
    echo -e "\n\t\e[1;32;47mPartitioning was successful\e[0m"
else
    echo -e "\n\t\e[5;31;47mPartitioning was NOT successful. Contact Staff.\e[0m"
fi
fdisk -l /dev/sda
sleep 3

