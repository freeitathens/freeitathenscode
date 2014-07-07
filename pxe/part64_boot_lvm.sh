#!/bin/bash
Accum_RC=0

Task_init() {
    Mess=${1:-'Unknown Task!'}
    local sleep_secs=${2:-3}
    echo -e "\e[0;33;40mPausing for $sleep_secs seconds...\e[0m"
    sleep $sleep_secs
    started_good='N'
    return 0
}

Good_mess() {
    mess=$@
    local RC=0
    started_good='Y'

    echo 'Good return code when '$mess'.'

    return $RC
}
Prob_mess() {
    local RC=$1
    shift
    mess=$@

    ((Accum_RC+=$RC))
    echo -e "\n\e[1;37;41mProblem! Non-zero return code ("$RC") when "$mess".\e[0m"
    echo -e "\n\e[0;37;43m<ENTER> (or wait 5 secs...) to continue\e[0m\n"
    read -t5 Xu

    return $RC
}

handle_possible_lvm() {
    local accum_RC=0

    echo -e "\e[1;31;40mCHECKING FOR POSSIBLE LVM (Logical Volume Management) Spaces:\e[1;37;41m"
    vgscan;pvscan
    if [ 0 -lt $((vgscan 2>/dev/null;pvscan 2>/dev/null) |wc -c) ]
    then
        echo -e "\e[0m\n\n\e[1;34;40mAttempting to remove all LVM Spaces:\e[0m"
        for VGr in $(vgscan |grep -o -P '".+"' |sed -e 's/"//g')
        do
            echo 'Removing Volume Group '$VGr
            vgremove --force $VGr || ((accum_RC+=$?))
        done
        for PVo in $(pvscan |grep 'PV' |sed -e 's/[ \t]\+/ /g' |cut -f3 -d' ')
        do
            if [[ $PVo =~ '/dev' ]]
            then
                echo 'Running pvremove on '$PVo
                pvremove $PVo || ((accum_RC+=$?))
            else
                pvscan
                echo 'Remove any physical lvm volumes manually'
                ((accum_RC+=128))
            fi
        done
    else
        echo 'No LVM Spaces. Please contact STAFF to diagnose error further.'
        ((accum_RC++))
    fi

    if [ $accum_RC -eq 0 ]
    then
        echo -e "\e[1;31;40mNow REBOOT \e[1;34;40m(Alt+F2; sudo /sbin/reboot).\n\t\e[1;31;40m Next time should be fine.\e[0m"
    else
        echo -e "\t\e[1;37;41m-->>\e[1;31;40m please RESCRUB this drive.\e[0m"
        echo -e "\t\e[1;37;41m-or>\e[1;31;40m CONTACT a staff member.\e[0m"
    fi
    read Xu

    return $accum_RC
}

Task_init 'Initializing partition table'
sudo parted -s /dev/sda mklabel msdos\
    && Good_mess $Mess\
    || Prob_mess $? $Mess
if [ $? -ne 0 ]
then
    handle_possible_lvm
fi

Task_init 'Creating boot partition'
sudo parted -s -a optimal /dev/sda unit MiB mkpart primary ext2 0% 513\
    && Good_mess $Mess\
    || Prob_mess $? $Mess

Task_init 'Creating extended' 
sudo parted -s -a optimal /dev/sda unit MiB mkpart extended 256 100%\
    && Good_mess $Mess\
    || Prob_mess $? $Mess

Task_init 'Creating main lvm partition' 
sudo parted -s -a optimal /dev/sda unit MiB mkpart logical ext2 257 73985\
    && Good_mess $Mess\
    || Prob_mess $? $Mess
Task_init 'Setting lvm flag on'
parted -s /dev/sda set 5 lvm on\
    && Good_mess $Mess\
    || Prob_mess $? $Mess

Task_init 'Making lvm-ready partition with extra space'
sudo parted -s -a optimal /dev/sda unit MiB mkpart logical ext2 73985 100%\
    && Good_mess $Mess\
    || Prob_mess $? $Mess
Task_init 'Setting lvm flag on extra'
parted -s /dev/sda set 6 lvm on\
    && Good_mess $Mess\
    || Prob_mess $? $Mess

if [ $Accum_RC -eq 0 ]
then
    echo -e "\n\t\e[1;32;40mPartitioning was successful\e[0m"
else
    echo -e "\n\t\e[5;31;40mPartitioning had issues. Contact Staff.<ENTER>\e[0m"
    read Xu
fi
echo -e "\nNewly created partition scheme:"
fdisk -l /dev/sda

sleep $sleep_secs

#sudo /sbin/sfdisk --change-id /dev/sda 5 8e

#ls -l /dev/sda*
#cat /sys/block/sda/sda <tab>
#echo 1 >/sys/block/sda/device/delete
#cat >/sys/class/scsi_host/hostN/device/target1\:0\:0/1\:0\:0\:0/model (use find or tab key after "scsi_host")
#echo '\''- - -'\'' > /sys/class/scsi_host/hostN/scan' "

