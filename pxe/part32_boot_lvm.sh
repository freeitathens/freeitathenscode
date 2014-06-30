#!/bin/bash
Accum_RC=0
Error_mess() {
    local RC=$1
    shift
    mess=$@
    echo 'Problem! Non-zero return code ('$RC') when '$mess'.'
    ((Accum_RC+=$RC))
    echo '<ENTER> to continue'
    read Xu
}
sudo parted -s /dev/sda mklabel msdos || Error_mess $? 'initializing partition table'
sleep 2
sudo parted -s -a optimal /dev/sda unit MiB mkpart primary ext2 1 513\
    || Error_mess $? 'creating boot partition'
sleep 2
sudo parted -s -a optimal /dev/sda unit MiB mkpart primary ext2 513 37193\
    || Error_mess $? 'creating primary lvm partition' 
sleep 2
sudo parted -s -a cylinder /dev/sda unit MiB mkpart primary ext2 37193 100%\
    || Error_mess $? 'making partition with extra space'
sleep 1
set 2 lvm on || Error_mess $? 'setting lvm flag on'

if [ $Accum_RC -eq 0 ]
then
    echo -e "\n\t\e[1;32;47mPartitioning was successful\e[0m"
else
    echo -e "\n\t\e[5;31;47mPartitioning had issues. Contact Staff.\e[0m"
fi
fdisk -l /dev/sda
sleep 1

