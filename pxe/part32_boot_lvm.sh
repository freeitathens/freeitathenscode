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

    echo -e "\e[0;32;40mGood return code for action "$mess".\e[0m"

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

Handle_possible_lvm() {
    local accum_RC=0

    echo -e "\e[0;32;40mCHECKING FOR LVM Spaces from a previous install\e[0m"
    vgscan;pvscan

    for VGr in $(vgscan 2>/dev/null|grep -o -P '".+"' |sed -e 's/"//g')
    do
        ((accum_RC+=1))
        echo 'Removing Volume Group '$VGr
        vgremove --force $VGr || ((accum_RC+=$?))
    done
    for PVo in $(pvscan 2>/dev/null|grep 'PV' |sed -e 's/[ \t]\+/ /g' |cut -f3 -d' ')
    do
        ((accum_RC+=2))
        if [[ $PVo =~ '/dev' ]]
        then
            echo 'Running pvremove on '$PVo
            pvremove $PVo || ((accum_RC+=$?))
        else
            echo 'Remove any physical LVM volumes manually'
            ((accum_RC+=128))
        fi
    done

    if [ $accum_RC -eq 0 ]
    then
        echo -e "\e[0;32;40mNo LVM Spaces. This is normal.\e[0m"
        return 0
    elif [ $accum_RC -lt 10 ] 
    then
        echo -e "\e[1;31;40mNow REBOOT \e[1;34;40m(Alt+F2; sudo /sbin/reboot).\e[0m"
        echo -e "\t\e[1;31;40mNext time should be fine.\e[0m"
    else
        echo -e "\t\e[1;37;41m-->>\e[1;31;40m please RESCRUB this drive.\e[0m"
        echo -e "\t\e[1;37;41m-or>\e[1;31;40m RC=${accum_RC}. CONTACT a staff member.\e[0m"
    fi
    echo -e "\n\t\e[1;35;40m(or <ENTER> to continue...)\e[0m"
    read Xu

    return $accum_RC
}

Handle_possible_lvm || exit $?

Task_init 'Initializing partition table'
sudo parted -s /dev/sda mklabel msdos\
    && Good_mess $Mess\
    || Prob_mess $? $Mess

Task_init 'Creating boot partition' 1
sudo parted -s -a optimal /dev/sda unit MiB mkpart primary ext2 0% 513\
    && Good_mess $Mess\
    || Prob_mess $? $Mess

Task_init 'Creating main LVM partition' 1
sudo parted -s -a optimal /dev/sda unit MiB mkpart primary ext2 513 37193\
    && Good_mess $Mess\
    || Prob_mess $? $Mess
Task_init 'Setting LVM flag on' 1
parted -s /dev/sda set 2 lvm on\
    && Good_mess $Mess\
    || Prob_mess $? $Mess

Task_init 'Making LVM-ready partition with extra space' 1
sudo parted -s -a optimal /dev/sda unit MiB mkpart primary ext2 37193 100%\
    && Good_mess $Mess\
    || Prob_mess $? $Mess
Task_init 'Setting LVM flag on extra' 1
parted -s /dev/sda set 3 lvm on\
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

#sudo /sbin/sfdisk --change-id /dev/sda 5 8e

#ls -l /dev/sda*
#cat /sys/block/sda/sda <tab>
#echo 1 >/sys/block/sda/device/delete
#cat >/sys/class/scsi_host/hostN/device/target1\:0\:0/1\:0\:0\:0/model (use find or tab key after "scsi_host")
#echo '\''- - -'\'' > /sys/class/scsi_host/hostN/scan' "

