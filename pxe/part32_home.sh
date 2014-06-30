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
sudo parted -s -a optimal /dev/sda unit GiB mkpart primary ext2 1 10
sudo parted -s -a optimal /dev/sda unit MiB mkpart linux-swap 9524 10000
sudo parted -s -a optimal /dev/sda unit MiB mkpart extended 10000 100%
sudo parted -s -a optimal /dev/sda unit MiB mkpart logical ext3 10001 56700
sudo parted -s -a optimal /dev/sda unit MiB mkpart logical ext3 56700 100%

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

fdisk -l /dev/sda

