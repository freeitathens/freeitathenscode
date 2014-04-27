#/bin/bash
cd || exit 3
# *--* (set -u) = Treat references to undeclared variables as an error
set -u
HOLD_IFS=$IFS
# *--* Ensure dialog program is installed.
type dialog &>/dev/null || {
    echo "The 'dialog' program must be installed for the QC script to work: will attempt to install ...";
    sudo apt-get update && sudo apt-get install dialog || exit 4
}

if test -z "$DISPLAY";then
    export DISPLAY=:0
fi

# *--* Identify box as 32 or 64 bit capable.
CPU_ADDRESS=32
CPUFLAGS=$(cat /proc/cpuinfo |grep '^flags')
for GL in $CPUFLAGS ;do if [ $GL == 'lm' ];then CPU_ADDRESS=64;fi;done

# *--* Create log file(s)
sudo rm QC*.log
touch QC.log || exit 5
touch QC_error.log
set +o noclobber
cat /dev/null >QC_error.log
set -o noclobber

Append_to_log() {
    MsgLvl=${1:-'ERROR'}
    Trans_MsgLvl=$(echo $MsgLvl |tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')
    MsgLvl=$Trans_MsgLvl


    Typ=${2:-'none'}
    shift 2

    MsgTxt=$@


    RC=0
    Message_level='UNDEFINED'
    Punct='.'
    case $MsgLvl in
    PASS)
    Message_level='PASSED'
    ;;
    INFO)
    Message_level='INFORMATIONAL'
    Punct='...'
    ;;
    NOTE)
    Message_level='NOTICE'
    ;;
    PROB)
    Message_level='PROBLEM'
    Punct='!'
    ;;
    WARN)
    Message_level='WARNING'
    Punct='!?'
    ;;
    ERROR)
    Message_level='SYSTEM ERROR'
    Punct='!!??'
    ;;
    esac

    MsgTyp=''
    if [ "$Typ" != 'none' ]
    then
        MsgTyp=' ('$Typ')'
    fi
    echo ${Message_level}${MsgTyp}':' ${MsgTxt}$Punct >>QC.log 

    return $RC
}

Window_killa() {
    local PID=$1
    [[ $PID -lt 2 ]] && return 5

    Sleep_max_secs=${2:-10}
    Sleep_counter=0

    while [ $PID -gt 0 ]
    do
        ((Sleep_counter++))
        [[ $Sleep_counter -gt 100 ]] && return 2
        if [[ $Sleep_counter -gt $Sleep_max_secs ]]
        then
            kill $PID 2>/dev/null
            Sleep_counter=0
        else
            ps -p $PID -o time= 2>/dev/null || PID=-1
        fi
        sleep 1
    done
}

Work_on_Optical() {
    [[ -z $TARGET_OPTICAL ]] && return 4
    TARGET_DEVICE="/dev/${TARGET_OPTICAL}"
    sudo eject -a off -i off $TARGET_DEVICE 2>>QC_error.log
    sudo eject $TARGET_DEVICE 2>>QC_error.log;RC=$?
    if [ $RC -eq 0 ];then
        dialog --keep-tite --colors --title "\Z7\ZrFree IT Athens Quality Control Test"\
            --pause "\Z1\Zu8 seconds\ZU\Z0 to remove any \Z1\ZuFrita CDs\Z0\ZU. (\Z4\ZrOK\ZR\Z0 closes drive quicker.)" 12 80 8
        dcd_RC=$?
        if [ $dcd_RC -eq 0 ]
        then
            sudo eject -t $TARGET_DEVICE ||\
                dialog --keep-tite --clear --colors --timeout 9 --ok-label "We're good" \
                --title "\Z5\ZrSimon Says Free I.T. Rocks" \
                --msgbox "\Z4\ZrPlease ensure optical drive is closed (Laptop?)." 10 70
        else
            dialog --keep-tite --clear --colors --timeout 8 --ok-label "Got it" \
                --title "\Z7\ZrFree IT Athens Quality Control Test" \
                --msgbox "\Z4\ZrPlease ensure optical drive is closed." 10 50
        fi
        if [ $optical_drive_count -gt 1 ]
        then
            Append_to_log 'INFO' 'CD/DVD drive test' 'More than one optical drive'
        fi
        Append_to_log 'PASS' 'CD/DVD drive test' 'Have at least one drive'
    else
        Append_to_log 'PROB' 'CD/DVD drive test' 'Cannot open Optical Drive at' $TARGET_DEVICE
    fi
}

Set_min_max_per_hardware_type() {
    # Set up MAX and MIN for Memory

    PROCESSORS=$(grep 'physical id' /proc/cpuinfo | sort -u | wc -l)
    CORES=$(grep 'core id' /proc/cpuinfo | sort -u | wc -l)

    RAM_VIDEO_MAX=0
    RAM_LOW_MULT=0
    RAM_HIGH_MULT=0

    if test $PROCESSORS -gt 1 -o $CORES -gt 1
    then
        Set_RAM_max_min_dual_core
    else
        Set_RAM_max_min_single_core
    fi

    RAM_LOW_TEXT=${RAM_LOW_MULT}'MiB'
    RAM_HIGH_TEXT=${RAM_HIGH_MULT}'MiB'
    RAM_LOW_VALUE=$((${RAM_LOW_MULT}*1024))
    RAM_HIGH_VALUE=$((${RAM_HIGH_MULT}*1024))

    # Set up MAX and MIN for Hard Drive
    FS_LOW_MULT=80
    FS_HIGH_MULT=1000
    if [ $CPU_ADDRESS -eq 32 ]
    then
        FS_LOW_MULT=60
        FS_HIGH_MULT=120
    fi

    FS_LOW_VALUE=$((${FS_LOW_MULT}*1000*1000*1000))
    FS_HIGH_VALUE=$((${FS_HIGH_MULT}*1000*1000*1000))
    FS_LOW_TEXT=${FS_LOW_MULT}'GB'
    FS_HIGH_TEXT=${FS_HIGH_MULT}'GB'

    #   160041885696 is 160GB in bytes at least for some drives

    return 0
}

Set_RAM_max_min_dual_core() {

    RAM_VIDEO_MAX=256
    RAM_LOW_MULT=$((2048-${RAM_VIDEO_MAX}))
    RAM_HIGH_MULT=3182
    #FS_LOW_VALUE=76000
    #FS_HIGH_VALUE=1000000

}

Set_RAM_max_min_single_core() {

    RAM_VIDEO_MAX=128
    RAM_LOW_MULT=$((1024-${RAM_VIDEO_MAX}))
    RAM_HIGH_MULT=2048
    IFS=$'\n';
    for Memtype in $(sudo dmidecode --type 17 |egrep -i '^\s*Type:' |sort --uniq |cut -f2 -d: |tr -s ' '|cut -f2 -d' ') 
    do
        case $Memtype in
            DDR2)
                echo 'have ddr2' >>QC_error.log
                RAM_HIGH_MULT=1024
		;;
            SDRAM)
                echo 'have sdram' >>QC_error.log
                ;;
            *)
                echo 'have RAM type' $Memtype
                ;;
        esac
    done
    return 0
}

# *--* Hard Drive Count *--*
Get_harddrive_count() {
    prime_disk=''
    prime_sectors=0
    sdx_sectors=0
    sdx_count=0
    for sdx in $(ls -d /sys/block/sd[a-w])
    do
        sdx_sectors=$(cat ${sdx}/size)
        if [ $sdx_sectors -gt 0 ]
        then
            [[ -z "$prime_disk" ]] && prime_disk=$sdx
            [[ $prime_sectors -eq 0 ]] && prime_sectors=$sdx_sectors
            ((sdx_count++))
        fi
    done
    if   test $sdx_count -eq 1
    then
        Append_to_log 'PASS' 'Hard drive count' 'Exactly one hard drive found'
    elif test $sdx_count -gt 1
    then
        Append_to_log 'NOTE' 'Hard drive count' 'Multiple Hard drives found'
    elif test $sdx_count -lt 1
    then
        Append_to_log 'PROB' 'Hard drive count' 'Huh? No Hard drives'
    fi
    total_bytes=$(echo "${prime_sectors}*$(cat $prime_disk/queue/hw_sector_size)" |bc)
    echo $total_bytes
    return 0
}

# *--* Optical drive(s) QC_test
TARGET_OPTICAL=''
optical_drive_count=0
for dev_path in $(ls -d /sys/block/sr*)
do
    dev_name=$(basename $dev_path)
    [[ -z $TARGET_OPTICAL ]] && TARGET_OPTICAL=$dev_name
    ((optical_drive_count++))
done
if   [ $optical_drive_count -lt 1 ]
then
    Append_to_log 'PROB' 'CD/DVD drive test' 'Need to add an optical drive'
else
    Work_on_Optical || Append_to_log 'ERROR' 'CD/DVD drive test' 'Cannot ID Optical Drive'
fi

# *--* network
dev_count=$(ls /sys/class/net | grep eth | wc -l)
if   test $dev_count -lt 1;then 
    Append_to_log 'PROB' 'Network card test' 'Network Card missing'
elif test $dev_count -gt 1;then
    Append_to_log 'INFO' 'Network card test' 'Too many network cards'
else
    Append_to_log 'PASS' 'Network card test' 'One network card detected'
fi

# *--* modem detection
dev_count=$(lspci | grep -i Modem | wc -l)
if test $dev_count -ge 1;then
    Append_to_log 'PROB' 'Modem test' 'Remove extra modem(s)!'
else
    Append_to_log 'PASS' 'Modem test' 'No excess modems'
fi

# *--* sound
dev_count=$(ls /sys/class/sound/ | grep card | wc -l)
if   test $dev_count -lt 1;then
    Append_to_log 'PROB' 'Sound card test' 'Missing sound card'
elif test $dev_count -gt 1;then
    Append_to_log 'NOTE' 'Sound card test' 'More than one sound card'
else
    Append_to_log 'PASS' 'Sound card test' 'One sound card found'
fi

# *--* video
dev_count=$(ls /sys/class/graphics/ | grep fb[0-9] | wc -l)
if   test $dev_count -lt 1;then
    Append_to_log 'PROB' 'Video card test' 'Missing video card'
elif test $dev_count -gt 1;then
    Append_to_log 'NOTE' 'Video card test' 'More than one video card'
else
    Append_to_log 'PASS' 'Video card test' 'One video card found'
fi

# *--* resolution
QCVAR=$(xrandr | grep '1024x768')
if test -z "$QCVAR";then
    Append_to_log 'PROB' 'Video resolution test' 'Resolution must be at least 1024x768'
else
    Append_to_log 'PASS' 'Video resolution test' 'Resolution is capable of 1024x768'
fi

# *--* usb
dev_count=$(ls /sys/bus/usb/devices | wc -l)
if test $dev_count -lt 1;then
    Append_to_log 'PROB' 'USB port test' 'There are no USB ports'
else
    Append_to_log 'PASS' 'USB port test' 'Box has USB ports'
fi

# *--* users
user_count=$(ls /home |grep -v 'lost+found' | wc -l)
if   test $user_count -lt 1;then
    Append_to_log 'PROB' 'User count test' 'No users found'
elif test $user_count -gt 1;then
    USEES=$(ls /home)
    Append_to_log 'PROB' 'User count test' 'Multiple users found, viz. '$USEES
else
    Append_to_log 'PASS' 'User count test' 'One user found'
fi
# Should also count uid's > 999 (minus nobody)

# *--* CPU speed
QCVAR=$(awk '/MHz/ {print $4; exit}' /proc/cpuinfo)
LEN=$(expr match $QCVAR '[0-9]*')
QCVAR=${QCVAR:0:$LEN}
if test $QCVAR -lt 1000;then
    Append_to_log 'PROB' 'CPU clockspeed test' 'Recycle this computer'
else
    Append_to_log 'PASS' 'CPU clockspeed test' 'Clockspeed 1 Ghz or greater'
fi

Set_min_max_per_hardware_type
total_disk_bytes=$(Get_harddrive_count)

#TEST
echo 'Total Disk (Bytes)='$total_disk_bytes >>QC_error.log
#ENDT
QCVAR=$(echo "((($total_disk_bytes/1024)/1024)/1024)" |bc)
#TEST
echo 'Disk Gibibytes='$QCVAR >>QC_error.log
#ENDT
if [ $total_disk_bytes -lt $FS_LOW_VALUE ]
then
    Append_to_log 'PROB' 'Hard drive size test' 'Hard drive should be at least' ${FS_LOW_TEXT}
elif [ $total_disk_bytes -gt $FS_HIGH_VALUE ]
then
    Append_to_log 'NOTE' 'Hard drive size test'\
        'Hard drive should be not more than' ${FS_HIGH_TEXT}
else
    Append_to_log 'PASS' 'Hard drive size test' 'Within bounds'
fi
# *--* RAM
QCVAR=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if test $QCVAR -lt $RAM_LOW_VALUE
then
    Append_to_log 'PROB' 'Memory size test' 'Add more so you have at least' ${RAM_LOW_TEXT}
elif test $QCVAR -gt $RAM_HIGH_VALUE
then
    Append_to_log 'NOTE' 'Memory size test' 'Remove some so you have not more than' ${RAM_HIGH_TEXT}
else
    Append_to_log 'PASS' 'Memory size test' 'Within bounds'
fi

# this file will exist if the user is running the QC script
# again after it hung during the 3D test
Lock_file="$HOME/Desktop/3D_Test_Started"
if [ -e $Lock_file ]
then
    echo "PROBLEM: 3D stability test. A previous test set a lock. Choose from:"
    select lockchoice in Clear_lock_and_retest Replace_card Disable_3D
    do break
    done
    case $lockchoice in
        Clear_lock_and_retest)
            rm -v $Lock_file ;;
        Replace_card)
            dialog --colors --title "\Z7\ZrFree IT Athens Quality Control Test"\
                --yesno 'Shutdown to replace video card?' 20 80
            D_rc=$?
            if [ $D_rc -eq 0 ];then
                sudo /sbin/shutdown -h now
            else
                echo 'Not doing anything!';sleep 3
            fi
            ;;
        Disable_3D)
            dialog --title "Free IT Athens Quality Control Test" --msgbox "Click Disable 3D Icon" 20 80
            ;;
    esac
fi
if [ ! -e $Lock_file ]
then
    if [ -f /usr/lib/xscreensaver/antspotlight ];then
    echo "10 second 3D test started" | tee $Lock_file
      # run a 3D screensaver in a window for 10 seconds then stop it
    /usr/lib/xscreensaver/antspotlight -window 2>>QC_error.log &
    PID=$!
    clear
    Window_killa $PID 9
    
    # if the computer doesnt hang, it passes
    rm -f $Lock_file
        Append_to_log 'PASS' '3D stability test' 'The ant is happy'
    else
        Append_to_log 'PROB' '3D stability test' 'This test is NOT possible'
    fi
fi

# *--* Test playing flash content
path2firefox=$(which firefox 2>/dev/null)
if [ ! -z "$path2firefox" ]
then
#
    #Test_ff_msg=
    dialog --keep-tite --clear --colors --title "\Z7\ZrFree IT Athens Quality Control Test"\
    --yesno "Test \Z4\ZrShockwave Flash\ZR \Z0in $path2firefox ?" 9 60
    d_RC=$?
    if [ $d_RC -eq 0 ]
    then
        $path2firefox -no-remote http://www.youtube.com/watch?v=mwbgwZxodKE 2>>QC_error.log &
        ice_PID=$!
        echo $ice_PID 'process # for ff' >>QC_error.log
        Window_killa $ice_PID 40
        Append_to_log 'INFO' 'Flash plugin test' 'Test was run'
        #(sleep 40;ps -p $ice_PID -o time= 2>/dev/null && Kill $ice_PID) &
        #'http://www.youtube.com/watch?v=7OXiS4BTXNQ' craxy cd-rom
    fi
else
    Append_to_log 'PROB' 'Flash plugin test' 'This test is NOT possible'
fi
# *--* sort to make problems more visible
set +o noclobber
sort -r QC.log > QC_sorted.log
set -o noclobber
# *--* 
echo -e "\n" >>QC_sorted.log
if [ $CPU_ADDRESS -eq 32 ]
then
    echo 'CPU is 32-bit.' >> QC_sorted.log
    #echo '(IF XFCE) Remember to save a default session for the new user!' >>QC_sorted.log
else
    echo 'CPU is 64-bit capable.' >> QC_sorted.log
    if [ 0 -eq $(uname -mpi |grep x86_64 |wc -l) ]
    then
        echo "You MIGHT want to re-install using a 64-bit kernel." >> QC_sorted.log
    fi
fi

summary_title="\Z7\ZrFree IT Athens Quality Control Test Results\Z0\ZR"

egrep '^(PROB|SYSTEM)' QC_sorted.log &>/dev/null;RC=$?
[[ $RC -gt 0 ]] || summary_title="\Z1Free IT Athens Quality Control Test Results\Z0"

dialog --keep-tite --colors --title "$summary_title" --textbox QC_sorted.log 25 80
clear

# *--* QC_Backend.sh Finished *--*
#TODO (for build) include tty fonts on libreoffice (or instructions)
#TODO Need test for flash content handling
#TODO Need change build to make separate partition for /home
#ls /sys/block/ | grep sr | wc -l)
#if test $QCVAR -eq 1
#elif test $QCVAR -gt 1
#elif test $QCVAR -lt 1
#QCVAR=$(df -m / | awk '/dev/ {print $4}')
#ram_hi=$(((1024*3)*1024))
#ram_lo=$(((1024*2)-256)*1024))
#=$(expr 1792 \* 1024)
#=$(expr 2048 \* 1024)

