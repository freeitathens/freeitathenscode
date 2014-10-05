#!/bin/bash
Down_late=${1:-'N'}

Merrors=~/QC.msg
sudo touch $Merrors
cat $Merrors |sudo tee -a ~/QC_msg.bak 2>/dev/null
set +C
#cat /dev/null |sudo tee ~/QC.msg
echo 'Start QC.sh on '$hostname' '$(date +%s) |sudo tee $Merrors

# this script should not perform or report on any QC checks itself
# it should only update the QC scripts and run the backend

if [ $Down_late == 'Y' ]
then
    echo "Downloading latest QC / imaging scripts" |sudo tee -a $Merrors
    svn update ~/freeitathenscode/{QC_Process,image_scripts} &
    # redirect (>) output to bitbucket (/dev/null) keeps user 
    # from being overwhelmed with not-so-relevent messages.
    if [ $? == 0 ]; then
        # $? is the exit status of the previous command
        # svn returns 0 on success and 1 on failure
        echo "Download succeeded" |sudo tee -a $Merrors
    else
        echo "Download failed, using existing version" |sudo tee -a $Merrors
    fi
fi

# whether we updated it or not, run the QC script
# If launched as 'QCM.sh' (from Master Box), prepare to update the hostname with Month and Day.
QCMast='N'
if [[ $0 =~ 'QCM' ]];then QCMast='M';fi
~/freeitathenscode/QC_Process/QC_Backend.sh $QCMast 2>&1 |sudo tee -a $Merrors

# *--*  Disabling 3D is very rare these days. But it still happens... *--*
[[ -e ~/Desktop/Disable_3D.desktop ]]\
    && ln -s ~/freeitathenscode/QC_Process/Disable_3D.desktop ~/Desktop/.

