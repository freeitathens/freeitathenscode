#!/bin/bash
Down_late=${1:-'N'}

# this script should not perform or report on any QC checks itself
# it should only update the QC scripts and run the backend

if [ $Down_late == 'Y' ]
then
    echo "Downloading latest QC script"
    svn update ~/freeitathenscode/QC_Process > /dev/null
    # redirect (>) output to bitbucket (/dev/null) keeps user 
    # from being overwhelmed with not-so-relevent messages.
    if [ $? == 0 ]; then
        # $? is the exit status of the previous command
        # svn returns 0 on success and 1 on failure
        echo "Download succeeded"
    else
        echo "Download failed, using existing version"
    fi
fi

#if [ ! -e ~/Desktop/Disable_3D.desktop ]; then
#   ln -s ~/freeitathenscode/QC_Process/Disable_3D.desktop ~/Desktop/.
#i

# whether we updated it or not, run the QC script
~/freeitathenscode/QC_Process/QC_Backend.sh
