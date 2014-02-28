#/bin/bash
cd ||exit 3
# *--* Treat references to undeclared variables as an error
set -u
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
# *--* Create log file
rm QC.log* 2> /dev/null
touch QC.log || exit 5
# *--* Optical drive(s) QC_test
TARGET_OPTICAL=''
for QCVAR in ls -d /sys/block/sr*
do
    if [ -z $TARGET_OPTICAL ]
    then
        echo "INFO : CD/DVD drive test. Too many optical drives exist!" >> QC.log
        break
    fi
    [[ -z $TARGET_OPTICAL ]] && TARGET_OPTICAL=$QCVAR
done
if [ -z $TARGET_OPTICAL ];then
    echo "PROBLEM : CD/DVD drive test. Add an optical drive!" >> QC.log
else 
    echo "PASSED  : CD/DVD drive test (Have at least one drive)" >> QC.log
    TARGET_DEVICE="/dev/${TARGET_OPTICAL}"
    eject $TARGET_DEVICE;RC=$?
    if [ $RC -eq 0 ];then
        #TODO special handling for laptops
        (sleep 8 && eject -t $TARGET_DEVICE) &
        dialog --title "Free IT Athens Quality Control Test"\
            --pause "remove any Frita CDs (I'll try to close the drive after ~8 seconds...)" 8 90 8;clear
        if [ $etRC -gt 0 ];then
            dialog --title "Uh Oh!" --pause "Please close the optical drive manually.Thanks."\
             12 50 5
        fi;clear)

        dialog --title "Free IT Athens Quality Control Test"\
            --pause "remove any Frita CDs (I'll try to close the drive after ~8 seconds...)" 8 90 8;clear
    else
        echo "PROBLEM: Cannot eject Optical Drive at $TARGET_DEVICE" >>QC.log
    fi
fi
    #$sleepeject_PID=$!
    #(sleep 8 && eject -t /dev/sr0) &

# *--* hdd
QCVAR=$(ls -d /sys/block/sd[a-z] |wc -l)
if test $QCVAR -eq 1;then
    echo "PASSED  : Hard drive test." >> QC.log
elif test $QCVAR -gt 1;then
    echo "WARNING : Hard drive test. Check that there is only one hard drive." >> QC.log
elif test $QCVAR -lt 1;then
    echo "PROBLEM : Hard drive test. Something went wrong with the test!" >> QC.log
fi

# *--* network
QCVAR=$(ls /sys/class/net | grep eth | wc -l)
if test $QCVAR -lt 1
then echo "PROBLEM : Network card test. There is no network card!" >> QC.log
elif test $QCVAR -gt 1
then echo "PROBLEM : Network card test. There are too many network cards!" >> QC.log
else
echo "PASSED  : Network card test." >> QC.log
fi

# *--* modem detection
QCVAR=$(lspci | grep -i Modem | wc -l)
if test $QCVAR -ge 1
then echo "PROBLEM : Modem test. Remove a modem from the computer!" >> QC.log
else echo "PASSED  : Modem test." >> QC.log
fi

# *--* sound
QCVAR=$(ls /sys/class/sound/ | grep card | wc -l)
if test $QCVAR -lt 1
then echo "PROBLEM : Sound card test. There is no sound card!" >> QC.log
elif test $QCVAR -gt 1
then echo "WARNING : Sound card test. Check that there is only one sound card." >> QC.log
else
echo "PASSED  : Sound card test." >> QC.log
fi

# *--* video
QCVAR=$(ls /sys/class/graphics/ | grep fb[0-9] | wc -l)
if test $QCVAR -lt 1
then echo "PROBLEM : Video card test. Something went wrong with the test!" >> QC.log
elif test $QCVAR -gt 1
then echo "PROBLEM : Video card test. There are too many video cards in the computer!" >> QC.log
else
echo "PASSED  : Video card test." >> QC.log
fi

# *--* resolution
QCVAR=$(xrandr | grep '1024x768')
if test -z "$QCVAR"
then echo "PROBLEM : Video resolution test. Resolution must be at least 1024x768!" >> QC.log
else
echo "PASSED  : Video resolution test." >> QC.log
fi

# *--* usb
QCVAR=$(ls /sys/bus/usb/devices | wc -l)
if test $QCVAR -lt 1
then echo "PROBLEM : USB port test. There are no USB ports!" >> QC.log
else
echo "PASSED  : USB port test." >> QC.log
fi

# *--* users
QCVAR=$(ls /home | wc -l)
if test $QCVAR -lt 1
then echo "PROBLEM : User count. Something is wrong with this test!" >> QC.log
elif test $QCVAR -gt 1
then echo "PROBLEM : User count. There is more than one user account!" >> QC.log
else
echo "PASSED  : User count test." >> QC.log
fi

# *--* CPU speed
QCVAR=$(awk '/MHz/ {print $4; exit}' /proc/cpuinfo)
LEN=$(expr match $QCVAR '[0-9]*')
QCVAR=${QCVAR:0:$LEN}
if test $QCVAR -lt 650
then echo "PROBLEM : CPU clockspeed test. Recycle this computer!" >> QC.log
else
    echo "PASSED  : CPU clockspeed test." >> QC.log
fi

PROCESSORS=$(grep 'physical id' /proc/cpuinfo | sort -u | wc -l)
CORES=$(grep 'core id' /proc/cpuinfo | sort -u | wc -l)

if test $PROCESSORS -gt 1 -o $CORES -gt 1
then
    FS_LOW_VALUE=70000
    #FS_LOW_VALUE=65200   #65271 for forgiving image part
    FS_HIGH_VALUE=1000000
    FS_TEXT="80GB to 1TB"
    # up to 128MB of shared memory for video
    RAM_LOW_VALUE=$(expr 1920 \* 1024)
    RAM_HIGH_VALUE=$(expr 2048 \* 1024)
    RAM_TEXT="2GB"
else
    FS_LOW_VALUE=5001
    FS_HIGH_VALUE=80000
    FS_TEXT="10 to 80GB"
    # up to 32MB of shared memory for video
    RAM_LOW_VALUE=$(expr 480 \* 1024)
    RAM_HIGH_VALUE=$(expr 1024 \* 1024)
    RAM_TEXT="1GB"
fi

# *--* filesystem size
QCVAR=$(df -m / | awk '/dev/ {print $4}')
if test $QCVAR -lt "$FS_LOW_VALUE" -o $QCVAR -gt "$FS_HIGH_VALUE"
then echo "PROBLEM : Free space test. Hard drive should be $FS_TEXT." >> QC.log
else echo "PASSED  : Free space test." >> QC.log
fi

# *--* RAM
QCVAR=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if test $QCVAR -lt $RAM_LOW_VALUE
then echo "PROBLEM : Memory test. Add more so you have $RAM_TEXT." >> QC.log
elif test $QCVAR -gt $RAM_HIGH_VALUE
then echo "WARNING : Memory test. Remove some so you have $RAM_TEXT." >> QC.log
else
echo "PASSED  : Memory test." >> QC.log
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
            dialog --title "Free IT Athens Quality Control Test"\
                --yesno 'Shutdown to replace video card?' 20 80
            D_rc=$?
            if [ $D_rc -eq 0 ];then
                sudo /sbin/shutdown -h now
            else
                echo 'Not doing anything!';sleep 3
            fi
            ;;
        Disable_3D)
            dialog 'Click Disable 3D Icon';;
            dialog --title "Free IT Athens Quality Control Test" --textbox 'Click Disable 3D Icon' 20 80
    esac
fi
if [ ! -e $Lock_file ]
then
    echo "10 second long 3D test started" | tee $Lock_file
    # run a 3D screensaver in a window for 10 seconds then stop it
    /usr/lib/xscreensaver/antspotlight -window &
    PID=$!
    #dialog --title "Free IT Athens Quality Control Test"\
    #    --pause '10 second 3D test started' 8 90 10;clear
    sleep 10
    kill $PID
    # if the computer doesnt hang, it passes
    rm -f $Lock_file
    echo "PASSED  : 3D stability test." >> QC.log
fi

# *--* sort to make problems more visible
sort -r QC.log > QC.sorted.log
if [ $CPU_ADDRESS == '32' ]
then
    #echo 'This is a 32 bit box (running XFCE)'
    echo 'Remember to save the first XFCE session for the new user!' >>QC.sorted.log
fi

#output log to dialog box for ease of reading
dialog --title "Free IT Athens Quality Control Test Results" --textbox QC.sorted.log 20 80
clear
#TODO (for build) include tty fonts on libreoffice (or instructions)
#TODO Need test for flash content handling
#TODO Need change build to make separate partition for /home
# Note to geekaholics: 
#     existence of : /home/"Newuser"/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml:    <property name="SessionName" type="string" value="Default"/>

