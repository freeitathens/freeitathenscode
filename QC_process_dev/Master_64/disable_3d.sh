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

mult_chk=0
#if [ ! -z $XORGCONFIG ]
for Xdir in /{etc,usr/{etc,lib}}{/X11{,/xorg.conf.d}} /etc
do
    echo -n 'Trying' $Xdir '...'
    if [ -d $Xdir ]
    then
        echo ' ...Success...';ls -ld $Xdir |tr '\n' ' '
        for Xconf in $(find ${Xdir} -name 'xorg.conf*' |egrep -v '\.bak')
        do
	    if [ -f $Xconf ]
            then
                echo '......... And found ' $Xconf
	        #perl -pi'.bak' -e 's/DRI\s+True/DRI false/i' $Xconf
                diff ~/freeitathenscode/QC_Process/xorg.conf.template $Xconf |less
                ((mult_chk++))
            fi
        done
    fi
done

if [ $mult_chk eq 1 ]
then
    echo 'Had multiple xorg.conf files'
    #    sudo cp ~/freeitathenscode/QC_Process/xorg.conf.template $Xconf
fi

dialog --title "Free IT Athens Quality Control Test"\
    --msgbox 'Have completed copying an xorg.conf overlay to disable 3D' 10 40
dialog --title "Free IT Athens Quality Control Test" --msgbox ' restart X to test new configuration' 10 40
#sudo service mdm restart

