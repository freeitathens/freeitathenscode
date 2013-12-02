#!/bin/bash

Lock_file="$HOME/Desktop/3D_Test_Started"
# Remove lockfile for 3D test so it will run on next QC attempt
if [ -e $Lock_file ]
then
    rm -f $Lock_file
fi

# create X configuration with DRI disabled
# JxI 2013-11-29: Following contains only what's needed to override
# /etc/xorg.conf.d scripts...
sudo updatedb
X_Dest_Dir=''
mult_chk=0
for XDir in $(locate -r '/xorg\.conf$' |grep -v '/man' |xargs -r -I {} dirname {} |sort --uniq)
do
    X_Dest_Dir=$XDir
    ((mult_chk++))
done
if [ $mult_chk eq 1 ]
then
    perl -pi'.bak' -e 's/DRI\s+True/DRI false/i' $X_Dest_Dir/xorg.conf
else
    X_Dest_Dir=''
    mult_chk=0
    for XDir in $(locate -r '/xorg\.conf\.d' |grep -v '/man' |xargs -r -I {} dirname {} |sort --uniq)
    do
        X_Dest_Dir=$XDir
        ((mult_chk++))
    done
    if [ $mult_chk eq 1 ]
        sudo cp ~/freeitathenscode/QC_Process/xorg.conf.template $X_Dest_Dir/xorg.conf
    fi
fi

dialog --title "Free IT Athens Quality Control Test" --msgbox 'Have completed copying an xorg.conf overlay to disable 3D' 20 80
dialog --title "Free IT Athens Quality Control Test" --msgbox ' restart X to test new configuration' 49 39
#sudo service mdm restart

