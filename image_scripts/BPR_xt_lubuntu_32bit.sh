#!/bin/bash
Refresh_apt=${1:-'N'}
Refresh_git=${2:-'N'}
shift 2
source ${HOME}/freeitathenscode/image_scripts/Common_functions || exit 12
Messages_O=$(mktemp -t "$(basename $0)_report.XXXXX")

DOWNLOADS=${HOME}/Downloads
[[ -d ${DOWNLOADS} ]] || DOWNLOADS=/tmp

#Start BPR Configs
Configs_from_github() {

    local RC=0
    declare -r HOLDIFS=$IFS

    declare -r shopts_list='dotglob nullglob'
    declare -r reset_shopts_list=$(shopt -p |tr '\n' ';')
    Pauze 'Reset shopts with '$reset_shopts_list
    Activate_shopts $shopts_list

    sudo apt-get install git
    Git_name=FRITAdot
    cd $DOWNLOADS || exit 12
    git clone https://github.com/bpr97050/${Git_name}.git

    Git2Frita_DIR=${PWD}/$Git_name
    #rm -rf ${Git2Frita_DIR}/.git
    cd $Git2Frita_DIR || return 13
    sudo rsync -aRv --exclude '.git' . /etc/skel
    cd
    rm -rf $Git2Frita_DIR

    Reset_shopts $shopts_list $reset_shopts_list
    return $RC
}
Activate_shopts() {
    local shopts_list=$1
    [[ -z "$shopts_list" ]] && return 4
    local RC=0

    IFS=$' '
    for name_shopt in $shopts_list
    do
        shopt -s $name_shopt || ((RC+=$?))
    done
    IFS=$HOLDIFS

    return $RC
}
Reset_shopts() {
    local shopts_list=$1
    [[ -z "$shopts_list" ]] && return 5
    local reset_list=$2
    [[ -z "$reset_list" ]] && return 4
    local RC=0

    IFS=$' '
    for name_shopt in $shopts_list
    do
        echo $reset_list |egrep -o "(^|;)shopt -u $name_shopt(;|$)" && shopt -u $name_shopt
    done
    IFS=$HOLDIFS

    shopt |grep 'on' >&2
    return $RC
}

Chromium_stuff() {

    local RC=0

    if [ "${Refresh_apt}." == 'Y.' ]
    then
        sudo apt-get update &>>${Messages_O} &
        Time_to_kill $! "Running apt-get update. Details in $Messages_O"
    fi
    sudo apt-get install chromium-browser
    #sudo add-apt-repository ppa:skunk/pepper-flash
    #sudo apt-get install pepflashplugin-installer\
    #   && echo '. /usr/lib/pepflashplugin-installer/pepflashplayer.sh'\
    #   |sudo tee -a /etc/chromium-browser/default

    cd $DOWNLOADS
    #Pepperflash/Multimedia codecs installer
    check_install_RC=1
    wget -O check https://gist.githubusercontent.com/bpr97050/9899740/raw\
        && sudo mv check /usr/local/bin/\
        && sudo chmod +x /usr/local/bin/check\
        && check_install_RC=0

    # Option for user to install non-free multimedia stuff for Chrom[e|ium]
    if [ $check_install_RC -eq 0 ]
    then
        Answer='N'
        Pause_n_Answer 'Y|N' 'INFO,Install non-free Multimedia packages for Chrome?'
        if [ "${Answer}." == 'Y.' ]
        then
            Mess='non-free Multimedia install '
            tackon='OK'
            sudo /usr/local/bin/check || tackon='NOT OK'
            Pauze "$Mess$tackon"
        fi
    fi

    wget -O master_preferences\
        https://gist.githubusercontent.com/bpr97050/a714210a8759b7ccc89c/raw/\
        && sudo mv master_preferences /etc/chromium-browser/

    #Bookmarks
    wget -O default_bookmarks.html https://gist.github.com/bpr97050/b6b5679f94d344879328/raw\
        && sudo mv default_bookmarks.html /etc/chromium-browser
    cd -

    #Chromium Flags
    sudo sed -i 's/CHROMIUM_FLAGS=""/CHROMIUM_FLAGS="--start-maximized\
        --disable-new-tab-first-run --no-first-run\
        --disable-google-now-integration"/g' /etc/chromium-browser/default

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

Pauze "BPR code apt-get update. Renew apt is $Refresh_apt"

sudo apt-get update &>>${Messages_O} &
Time_to_kill $! "Running apt-get update. Details in $Messages_O"

if [ "${Refresh_apt}." == 'Y.' ]
then
    Pauze 'BEN Apt_stuff'
    Apt_stuff || echo 'Apt?'
fi

if [ $Refresh_git == 'Y' ]
then
    Pauze 'BEN Configs_from_github (partly cond)'
    Configs_from_github || echo 'Configs_from_github?'
fi

#Set LightDM wallpaper
sudo sed -i 's/background=/#background=/g' /etc/lightdm/lightdm-gtk-greeter.conf
sudo echo "background=#FFFFFF" >> /etc/lightdm/lightdm-gtk-greeter.conf

Pauze "Ben Chromium_stuff (partly cond, Redo apt is $Refresh_apt . Redo git is $Refresh_git )"
Chromium_stuff || echo 'Chromium Config?'

#Auto security upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
sudo apt-get --purge autoremove
sudo apt-get autoclean

Pauze "INFO,Finished with BPR custom code. last RC: $?"

#Only notify about LTS starting July 24th
#https://help.ubuntu.com/community/PreciseUpgrades
#End BPR Configs

    #Wine stuff in case the user needs to run a Windows executable
    #udo apt-get install wine winetricks
    #Upgrade to Trusty
    #sudo do-release-upgrade
    # NOT! Messes with keyboard! Remove Ibus
    #sudo apt-get purge --auto-remove ibus

