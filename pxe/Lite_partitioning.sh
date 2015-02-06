#!/bin/bash
declare -i Accum_RC=0
declare -i Fix_RC=0

Mainline() {

    Handle_possible_lvm || Fix_RC=$?
    [[ $Fix_RC -ge 10 ]] && exit $Fix_RC
    Accum_RC=$Fix_RC

    Set_Mess 'Initializing partition table'
    sudo parted -s /dev/$drivepart mklabel msdos\
	&& Good_mess $Mess\
	|| Prob_mess $? $Mess

    Set_Mess 'Creating root partition'
    sudo parted -s -a optimal /dev/$drivepart unit s mkpart primary ext4 2048 19531775\
	&& Good_mess $Mess\
	|| Prob_mess $? $Mess

    Set_Mess 'Creating swap partition'
    sudo parted -s -a optimal /dev/$drivepart unit s mkpart primary linux-swap 19531776 21485567\
	&& Good_mess $Mess\
	|| Prob_mess $? $Mess
    Set_Mess 'Formatting swap partition' 
    mkswap /dev/sda2\
	&& Good_mess $Mess\
	|| Prob_mess $? $Mess

    Set_Mess 'Creating extended partition'
    sudo parted -s -a optimal /dev/$drivepart unit s mkpart extended 21487614 100%\
	&& Good_mess $Mess\
	|| Prob_mess $? $Mess

    Set_Mess 'Creating home partition'
    sudo parted -s -a optimal /dev/$drivepart unit s mkpart logical ext4 21487616 100%\
	&& Good_mess $Mess\
	|| Prob_mess $? $Mess

    return $Accum_RC
}

Handle_possible_lvm() {
    local accum_RC=0

    echo -e "\e[0;32;40mCHECKING FOR LVM Spaces from a previous install\e[0m"
    vgscan
    pvscan

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
        echo -e "\e[1;31;40mCleared up LVM \e[1;34;40m....continuing\e[0m"
        sleep 5
    else
        echo -e "\t\e[1;37;41m-->>\e[1;31;40m please RESCRUB this drive.\e[0m"
        echo -e "\t\e[1;37;41m-or>\e[1;31;40m RC=${accum_RC}. CONTACT a staff member.\e[0m"
    fi
    echo -e "\n\t\e[1;35;40m(or <ENTER> to continue...)\e[0m"
    read Xu

    return $accum_RC
}

Set_Mess() {
    Mess=${1:-'Unknown Task!'}
    local sleep_secs=${2:-3}

    echo -e "\e[7;33;40mPausing for $sleep_secs seconds...\e[0m"
    sleep $sleep_secs
    started_good='?'

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

Mainline

if [ $Accum_RC -eq 0 ]
then
    echo -e "\n\t\e[1;32;40mPartitioning was successful\e[0m"
else
    echo -e "\n\t\e[5;31;40mPartitioning had issues. Contact Staff.<ENTER>\e[0m"
    read Xu
fi
echo -e "\nNewly created partition scheme:"
fdisk -l /dev/$drivepart

#Task_init 'Creating extended' 1
#sudo parted -s -a optimal /dev/sda unit MiB mkpart extended 513 100%\
#    && Good_mess $Mess\
#    || Prob_mess $? $Mess

