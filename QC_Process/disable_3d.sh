#!/bin/bash


# Remove lockfile for 3D test so it will run on next QC attempt
if [ -e ~/Desktop/3D_Test_Started ]
then
    rm ~/Desktop/3D_Test_Started
fi

# create X configuration with DRI disabled
sudo cp ~/freeitathenscode/QC_Process/xorg.conf.template /etc/X11/xorg.conf

# restart X using new configuration
sudo service gdm restart
