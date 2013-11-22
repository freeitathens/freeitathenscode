#!/bin/bash

# this script should not perform or report on any QC checks itself
# it should only update the QC scripts and run the backend

# redirecting output keeps the screen clear from confusing messages
echo "Downloading latest QC script"
svn update ~/freeitathenscode/QC_Process > /dev/null

# $? is the exit status of the previous command
# svn returns 0 on success and 1 on failure
if [ $? == 0 ]; then
	echo "Download succeeded"
else
	echo "Download failed, using existing version"
fi

# Can remove when new image created that has this
if [ ! -e ~/Desktop/Disable\ 3D.desktop ]; then
	ln -s ~/freeitathenscode/QC_Process/Disable\ 3D.desktop ~/Desktop/Disable\ 3D.desktop
fi

# whether we updated it or not, run the QC script
~/freeitathenscode/QC_Process/QC_Backend.sh
