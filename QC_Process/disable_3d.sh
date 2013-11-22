#!/bin/bash

Lock_file="$HOME/Desktop/3D_Test_Started"
# Remove lockfile for 3D test so it will run on next QC attempt
if [ -e $Lock_file ]
then
    rm -f $Lock_file
fi

# create X configuration with DRI disabled
#TODO JHI 2013-11-xx: Following is out-of-date since mint uses xorg.conf.d/* scripts...
#sudo cp ~/freeitathenscode/QC_Process/xorg.conf.template /etc/X11/xorg.conf

dialog --title "Free IT Athens Quality Control Test" --msgbox 'Dude, you need to manually disable 3d!'  20 80

# restart X using new configuration
#sudo service gdm restart

