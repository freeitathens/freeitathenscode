#!/bin/bash
Refresh_apt=${1:-'Y'}
Refresh_git=${2:-'Y'}
[[ -z "${Runner_shell_as}" ]] && Runner_shell_as=$3
[[ -z "${Runner_shell_as}" ]] && Runner_shell_as=$-
shift 3

#source ${HOME}/freeitathenscode/image_scripts/Common_functions || exit 12
source /usr/local/bin/Common_functions || exit 12

declare -x Messages_O=$(mktemp -t "$(basename $0)_report.XXXXX") 2>/dev/null
declare -r HOLDIFS=$IFS 2>/dev/null
DOWNLOADS=${HOME}/Downloads
[[ -d ${DOWNLOADS} ]] || mkdir ${HOME}/Downloads
[[ -d ${DOWNLOADS} ]] || exit 13

#Start BPR Configs
Configs_from_github() {
    local RC=0

    Shopts_keep_settings=$(mktemp -t "SHOPTS_KEEP.XXXXX" || echo '/tmp/Mktmp_error')
    shopt -p >$Shopts_keep_settings
    Pauze 'Reset shopts by sourcing '$Shopts_keep_settings
    declare -r shopts_seton_list='dotglob nullglob'
    Activate_shopts $shopts_seton_list

    Git_name=FRITAdot
    cd $DOWNLOADS || RC=$?
    [[ $RC -eq 0 ]]\
        && ( rm -rf ${Git_name}/ 2>/dev/null\
             && git clone https://github.com/bpr97050/${Git_name}.git || RC=$? )

    [[ $RC -eq 0 ]]\
        && ( sudo rsync -aRv --exclude '.git' --delete-excluded\
            ${Git_name}/\
            /etc/skel || RC=$? )

    cd
    Reset_shopts $Shopts_keep_settings
    return $RC
}
#declare -r shopts_original_list=$(shopt -p |tr '\n' ';')

Activate_shopts() {
    local shopts_seton_list=$1
    [[ -z "$shopts_seton_list" ]] && return 4
    local RC=0

    IFS=' '
    for name_shopt in $shopts_seton_list
    do
        shopt -s $name_shopt &>/dev/null || ((RC+=$?))
    done
    IFS=$HOLDIFS

    return $RC
}

Reset_shopts() {
    local Shopts_file=$1
    [[ -z "$Shopts_file" ]] && return 5
    local RC=0

    source $Shopts_file || RC=$?
    # Send a list of active short options to std err
    shopt |grep 'on' >&2

    return $RC
}

Run_apt_update() {

    sudo apt-get update &>>${Messages_O} &
    Time_to_kill $! "Running apt-get update. Details in $Messages_O"
    Refresh_apt='N'

}

Chromium_stuff() {

    local RC=0

    if [ "${Refresh_apt}." == 'Y.' ]
    then
	Run_apt_update
    fi
    sudo apt-get install chromium-browser

    # Ensure "/etc/chromium-browser" is a directory (not a file)
    [[ -e /etc/chromium-browser ]]\
        && ( [[ -d /etc/chromium-browser ]] || sudo mv -iv /etc/chromium-browser /tmp/ )
    [[ -d /etc/chromium-browser ]] || sudo mkdir /etc/chromium-browser

    cd $DOWNLOADS

    Answer='N'
    Pause_n_Answer 'Y|N' 'Git-Load Chromium Master Preferences?'
    if [ $Answer == 'Y' ]
    then
	# Download master_preferences config file for chromium
	wget -O master_preferences\
	    https://gist.githubusercontent.com/bpr97050/a714210a8759b7ccc89c/raw/\
	    && sudo mv master_preferences /etc/chromium-browser/
    fi

    Answer='N'
    Pause_n_Answer 'Y|N' 'Set chrome defaults?'
    if [ $Answer == 'Y' ]
    then
	# Ensure certain Chromium Flags settings are in place.
	sudo sed -i 's/CHROMIUM_FLAGS=""/CHROMIUM_FLAGS="--start-maximized\
	    --disable-new-tab-first-run --no-first-run\
	    --disable-google-now-integration"/g' /etc/chromium-browser/default
    fi

    Answer='N'
    Pause_n_Answer 'Y|N' 'Git-Load default_bookmarks.html?'
    if [ $Answer == 'Y' ]
    then
	# Download default bookmarks for Chromium
	wget -O default_bookmarks.html\
	    https://gist.github.com/bpr97050/b6b5679f94d344879328/raw\
	    && sudo mv default_bookmarks.html /etc/chromium-browser/
    fi

    Answer='N'
    Pause_n_Answer 'Y|N' 'Git-Load one-time Proprietary setup script?'
    if [ $Answer == 'Y' ]
    then
	check_install_RC=1
	#Pepperflash/Multimedia codecs installer
	wget -O check https://gist.githubusercontent.com/bpr97050/9899740/raw\
	    && sudo mv check /usr/local/bin/\
	    && sudo chmod +x /usr/local/bin/check\
	    && check_install_RC=0
	if [ $check_install_RC -eq 0 ]
	then
	    Answer='N'
	    Pause_n_Answer 'Y|N' 'WARN,Setup firstboot option to offer non-free Multimedia?'
	    if [ "${Answer}." == 'Y.' ]
	    then
		Mess='non-free Multimedia install '
		tackon='OK'
		#sudo /usr/local/bin/check || tackon='NOT OK'
		#Pauze "$Mess$tackon"
		Pauze 'Make icon on desktop that runs /usr/bin/check'
	    fi
	fi
    fi

    return $RC
}

Apt_stuff() {

    local RC=0

    #Remove unnecessary programs
    Apt_purge 'ace-of-penguins abiword abiword-common libabiword-3.0 gnumeric gnumeric-common'
    ((RC+=$?))

    #Printing
    Apt_install 'system-config-printer-gnome libprinterconf-dev'
    ((RC+=$?))

    #Replace Sylpheed with Claws Mail (looks similar to Outlook, more feature complete like Outlook)
    Apt_action_replace 'sylpheed'\
        'claws-mail claws-mail-extra-plugins claws-mail-tools claws-mail-plugins'
    ((RC+=$?))

    #Music (replace Audacious with Rhythmbox for Ipod support)
    Apt_action_replace 'audacious' 'libimobiledevice4 rhythmbox rhythmbox-plugins'
    ((RC+=$?))

    #Replace Mplayer with VLC (VLC seems to be more user friendly and less buggy)
    Apt_action_replace 'gnome-mplayer' 'vlc'
    ((RC+=$?))

    # Make sure git version control manager is installed
    Apt_install git

    return $RC
}
Apt_purge() {
    local packages=$1
    [[ -z $packages ]] && return 4

    local RC=0
    sudo apt-get purge --auto-remove $packages 2>>${Messages_O} || RC=$?

    return $RC
}
Apt_install() {
    local packages=$1
    [[ -z $packages ]] && return 4

    local RC=0
    sudo apt-get install $packages 2>>${Messages_O} || RC=$?

    return $RC
}
Apt_action_replace() {
    local packages=$1
    [[ -z $packages ]] && return 4
    shift 1
    local replacements=$@

    local RC=0
    echo 'Attempting to replace' $packages 'with' $replacements
    Apt_purge $packages ||RC=$?
    if [ $RC -eq 0 ]
    then
        Apt_install $replacements ||RC=$?
    fi

    return $RC
}

if [ "${Refresh_apt}." == 'Y.' ]
then
    Pauze "BPR code apt-get update. Renew apt is $Refresh_apt"
    Run_apt_update
fi

Pauze 'BPR Apt stuff'
Apt_stuff || Pauze 'Some apt-get action did not complete (perhaps postponing install(s)?.)'

if [ $Refresh_git == 'Y' ]
then
    Pauze 'BPR Configs_from_github (partly cond)'
    Configs_from_github || echo 'Configs_from_github?'
fi

#Set LightDM wallpaper
for greetings in $(find /etc/lightdm/ -mindepth 1 -maxdepth 1 -type f -name 'lightdm-gtk-greeter*')
do
    Answer='N'
    Pause_n_Answer 'Y|N' 'INFO,reset background in '$greetings'?'
    if [ "${Answer}." == 'Y.' ]
    then 
        sudo sed -i 's/^background=/#background=/g' $greetings
        echo "background=#CC00FF" | sudo tee -a $greetings
    fi
done
#sudo sed -i 's/^background=/#background=/g' /etc/lightdm/lightdm-gtk-greeter.conf

Pauze "BPR Chromium_stuff (partly cond, Refresh apt cache? $Refresh_apt . Download from github? $Refresh_git )"
Chromium_stuff || echo 'Chromium Config?'

#Auto security upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
sudo apt-get --purge autoremove
sudo apt-get autoclean

Pauze "INFO,Finished with BPR custom code. last RC: $?"

#Only notify about LTS starting July 24th
#https://help.ubuntu.com/community/PreciseUpgrades
#End BPR Configs

    #sudo add-apt-repository ppa:skunk/pepper-flash
    #sudo apt-get install pepflashplugin-installer\
    #   && echo '. /usr/lib/pepflashplugin-installer/pepflashplayer.sh'\
    #   |sudo tee -a /etc/chromium-browser/default

    #Wine stuff in case the user needs to run a Windows executable
    #udo apt-get install wine winetricks
    #Upgrade to Trusty
    #sudo do-release-upgrade
    # NOT! Messes with keyboard! Remove Ibus
    #sudo apt-get purge --auto-remove ibus

