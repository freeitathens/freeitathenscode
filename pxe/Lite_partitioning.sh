#!/bin/bash
declare disk=${1:-'sda'}
declare units_IN=${2:-'MiB'}
declare units_OUT=${3:-'MB'}
declare check_for_lvm=${4:-'Y'}

declare -i Accum_RC=0

Mainline() {

    for part_in_swap in $(swapon -sv |grep -P -o '/dev/'$disk'\d')
    do
        sudo swapoff $part_in_swap
    done

    declare -i partno=0

    Set_Mess 'Initializing gpt partition table'
    sudo parted -s /dev/$disk mklabel gpt;Mrc=$?
    Proc_mess $Mrc $Mess

    ((partno++))
    Part_ish_own 0% 1 'grubbios'
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    ((partno++))
    Part_ish_own $(($end+1)) $(((94*1024)/10)) 'boot'
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    ((partno++))
    Part_ish_own $(($end+1)) $(((94*1024)/10)) 'root'
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    ((partno++))
    Part_ish_own $(($end+1)) 1024 'swap'
    Set_Mess 'Formatting swap partition' 
    mkswap /dev/$disk${partno}
    Proc_mess $? $Mess
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    ((partno++))
    # 100%!!
    Part_ish_own $(($end+1)) $(((570*1024)/10)) 'home'
    [[ $Accum_RC -gt 5 ]] && return $Accum_RC

    return 0
}

Part_ish_own() {
    declare start=${1:-1024}
    declare -i len=${2:-1024}
    declare label=$3
    [[ -z $label ]] && label='part'$partno
    
    Set_Mess 'Creating '$label' partition (#'$partno')'
    Unit_conversion $len
    declare -ig end=$((${start}+${part_len}))

    parttype='ext4'
    [[ $label =~ 'swap' ]] && parttype='linux-swap'
    sudo parted -s -a optimal /dev/$disk unit $units_OUT mkpart $label $parttype $start $end
    Proc_mess $? $Mess;declare RC=$?

    return $RC
}
#udo parted -s            /dev/sdA unit s          mkpart root ext2 0% $end

Unit_conversion() {
    #declare units_IN=${1:-'MiB'}
    #declare units_OUT=${2:-'MB'}
    declare -i len_IN=$1

    declare -ig part_len=1
    case $units_IN in
        MiB)
            case $units_OUT in
                MB)
                    part_len=$(((($len_IN*1024*1024)/1000)/1000))
                    ;;
		MiB)
		    echo 'No units conversion needed on partition '$partno
		    ;;
		*)
		    echo 'Units value '$units_OUT' unknown'
		    ;;
            esac
	    ;;
	*)
	    echo 'Units value '$units_IN' unknown'
	    ;;
    esac
            
    return 0
}

# ((((10x1000x1000x1000)/1024)/1024)/1024) = 9.313225746
# (((10x1000x1000)/1024)/1024)             = 9.536743164

#  Example converting 74 MiB to sectors
#     end=$(((74*1024*1024)/512))

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
if [ $check_for_lvm == 'Y' ]
then
    Handle_possible_lvm || Fix_RC=$?
fi
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
parted -s /dev/$disk p

#sudo parted -s -a optimal /dev/sad unit MiB mkpart extended 513 100%\
#KNAME NAME     SIZE TYPE FSTYPE   MOUNTPOINT         MODEL
#sad   sad     74.5G disk                             Maxtor 6L080M0  
#mint@mint ~ $ Declare -i zart_len_MiB=$(((94*1024)/10))
#9625
#mint@mint ~ $ echo $(((9625*1024*1024)/512))
#19712000
#mint@mint ~ $ sudo parted /dev/sad
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sad: 80.0GB
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#(parted) unit MiB
#(parted) mkpart nameit ext2 0% 9625
#(parted) p                                                                
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sad: 76294MiB
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#Number  Start    End      Size     File system  Name    Flags
# 1      1.00MiB  9625MiB  9624MiB  ext4         nameit
#(parted) unit GiB
#(parted) p                                                                
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sad: 74.5GiB
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#
#Number  Start    End      Size     File system  Name    Flags
# 1      0.00GiB  9.40GiB  9.40GiB  ext4         nameit
#
#(parted) unit GB                                                          
#(parted) p                                                                
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sad: 80.0GB
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
#Disk /dev/sad: 156250000s
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
#mint@mint ~ $ sudo parted /dev/sad -s p
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sad: 80.0GB
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#
#Number  Start   End     Size    File system  Name    Flags
# 1      1049kB  10.1GB  10.1GB  ext4         nameit
#
#sudo parted /dev/sad -s unit s p
#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sad: 156250000s
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt
#
#Number  Start  End        Size       File system  Name    Flags
# 1      2048s  19711999s  19709952s  ext4         nameit

#Error: The location 2167197697 is outside of the device /dev/sad.

#Problem! Non-zero return code (1) when Creating swap partition (#2).

#Model: ATA Maxtor 6L080M0 (scsi)
#Disk /dev/sad: 156250000s
#Sector size (logical/physical): 512B/512B
#Partition Table: gpt

#Number  Start  End        Size       File system  Name  Flags
# 1      34s    19714048s  19714015s               root

