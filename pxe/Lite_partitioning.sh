#!/bin/bash
declare -i Accum_RC=0

Mainline() {

    Set_Mess 'Initializing gpt partition table'
    sudo parted -s /dev/sda mklabel gpt;Mrc=$?
    Proc_mess $Mrc $Mess

    declare -i start_sector=2048
    declare -i part_len_GiB=10
    declare -i part_len_MiB=$(((100*1024)/10))
    declare -i part_len_sectors=1
    declare -i end_sector=$(((74*1024*1024)/512))
    declare -i partno=0

    ((partno++))
    Set_Mess 'Creating root partition (#'$partno')'
    #sda1  |-sda1   9.3G part ext4                                                
    #part_len_GiB=9.4
    part_len_MiB=$(((94*1024)/10))
    part_len_sectors=$(((${part_len_MiB}*1024*1024)/512))
    end_sector=$((${start_sector}+${part_len_sectors}))
    sudo parted -s /dev/sda unit s mkpart root ext2 $start_sector $end_sector
    #sudo parted -s /dev/sda unit s mkpart root ext2 0% $end_sector
    Proc_mess $? $Mess
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    ((partno++))
    Set_Mess 'Creating swap partition (#'$partno')'
    start_sector=$((end_sector+1))
    #part_len_GiB=1
    part_len_MiB=1024
    part_len_sectors=$(((${part_len_MiB}*1024*1024)/512))
    end_sector=$((${start_sector}+${part_len_sectors}))
    sudo parted -s /dev/sda unit s mkpart 'swap' linux-swap\
	$start_sector $end_sector
    Proc_mess $? $Mess
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    Set_Mess 'Formatting swap partition' 
    mkswap /dev/sda${partno}
    Proc_mess $? $Mess
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    ((partno++))
    Set_Mess 'Creating dummy partition #1 (sda3)'
    start_sector=$((end_sector+1))
    part_len_MiB=1024
    part_len_sectors=$(((${part_len_MiB}*1024*1024)/512))
    end_sector=$((${start_sector}+${part_len_sectors}))
    sudo parted -s -a optimal /dev/sda unit s mkpart dummy1 ext2\
        $start_sector $end_sector
    Proc_mess $? $Mess
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    ((partno++))
    Set_Mess 'Creating dummy partition #2 (sda4)'
    start_sector=$((end_sector+1))
    part_len_MiB=1024
    part_len_sectors=$(((${part_len_MiB}*1024*1024)/512))
    end_sector=$((${start_sector}+${part_len_sectors}))
    sudo parted -s -a optimal /dev/sda unit s mkpart dummy2 ext2\
        $start_sector $end_sector
    Proc_mess $? $Mess
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    ((partno++))
    Set_Mess 'Creating home partition (#'$partno')'
    start_sector=$((end_sector+1))
    #sda5  sda5  56.1G part ext4                                                
    part_len_GiB=57
    part_len_MiB=$(((${part_len_GiB}*1024)/10))
    part_len_sectors=$(((${part_len_MiB}*1024*1024)/512))
    end_sector=$((${start_sector}+${part_len_sectors}))
    #udo parted -s -a optimal /dev/sda unit s mkpart home ext2
    sudo parted -s -a optimal /dev/sda unit s mkpart home ext2\
        $start_sector 100%
    Proc_mess $? $Mess
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    return 0
}

Set_Mess() {
    declare -g Mess=${1:-'Unknown Task!'}
    local sleep_secs=${2:-3}

    echo -e "\e[7;33;40mPausing for $sleep_secs seconds...\e[0m"
    sleep $sleep_secs
    started_good='?'

    return 0
}

Proc_mess() {
    declare -i last_RC=$1
    shift 1
    declare message=$@

    [[ $last_RC -eq 0 ]] && Good_mess $message && return 0

    Prob_mess $last_RC $message
    return $last_RC
}

Good_mess() {
    mess=$@

    started_good='Y'
    echo -e "\e[0;32;40mGood return code for action "$mess".\e[0m"

    return 0
}

Prob_mess() {
    declare RC=$1
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

declare -i Fix_RC=0
Handle_possible_lvm || Fix_RC=$?
[[ $Fix_RC -ge 10 ]] && exit $Fix_RC

Mainline

if [ $Accum_RC -eq 0 ]
then
    echo -e "\n\t\e[1;32;40mPartitioning was successful\e[0m"
else
    echo -e "\n\t\e[5;31;40mPartitioning had issues. Contact Staff.<ENTER>\e[0m"
    read Xu
fi
echo -e "\nNewly created partition scheme:"
parted -s /dev/sda p

#sudo parted -s -a optimal /dev/sda unit MiB mkpart extended 513 100%\
#KNAME NAME     SIZE TYPE FSTYPE   MOUNTPOINT         MODEL
#sda   sda     74.5G disk                             Maxtor 6L080M0  
#mint@mint ~ $ Declare -i zart_len_MiB=$(((94*1024)/10))
#9625
#mint@mint ~ $ echo $(((9625*1024*1024)/512))
#19712000
#mint@mint ~ $ sudo parted /dev/sda
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sda: 80.0GB
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#(parted) unit MiB
#(parted) mkpart nameit ext2 0% 9625
#(parted) p                                                                
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sda: 76294MiB
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#Number  Start    End      Size     File system  Name    Flags
# 1      1.00MiB  9625MiB  9624MiB  ext4         nameit
#(parted) unit GiB
#(parted) p                                                                
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sda: 74.5GiB
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#
#Number  Start    End      Size     File system  Name    Flags
# 1      0.00GiB  9.40GiB  9.40GiB  ext4         nameit
#
#(parted) unit GB                                                          
#(parted) p                                                                
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sda: 80.0GB
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#
#Number  Start   End     Size    File system  Name    Flags
# 1      0.00GB  10.1GB  10.1GB  ext4         nameit
#
#(parted) align-check minimal 1
#1 aligned
#(parted) align-check optimum 1                                            
#parted: invalid token: optimum
#alignment type(min/opt)  [optimal]/minimal? optimal                       
#Partition number? 1                                                       
#1 aligned
#(parted) unit s                                                           
#(parted) p                                                                
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sda: 156250000s
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#
#Number  Start  End        Size       File system  Name    Flags
# 1      2048s  19711999s  19709952s  ext4         nameit
#
#(parted) q                                                                
#Information: You may need to update /etc/fstab.                           
#
#mint@mint ~ $ echo $(((9625*1024*1024)/512))
#19712000
#mint@mint ~ $ sudo parted /dev/sda -s p
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sda: 80.0GB
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#
#Number  Start   End     Size    File system  Name    Flags
# 1      1049kB  10.1GB  10.1GB  ext4         nameit
#
#sudo parted /dev/sda -s unit s p
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sda: 156250000s
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#
#Number  Start  End        Size       File system  Name    Flags
# 1      2048s  19711999s  19709952s  ext4         nameit

#Error: The location 2167197697 is outside of the device /dev/sda.

#Problem! Non-zero return code (1) when Creating swap partition (#2).

#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sda: 156250000s
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt

#Number  Start  End        Size       File system  Name  Flags
# 1      34s    19714048s  19714015s               root

