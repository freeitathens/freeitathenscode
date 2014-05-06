#!/bin/bash
Refresh_apt=${1:-'N'}
Refresh_git=${2:-'N'}
shift 2
source ${HOME}/freeitathenscode/image_scripts/Common_functions || exit 12

DOWNLOADS=${HOME}/Downloads
[[ -d ${DOWNLOADS} ]] || DOWNLOADS=/tmp

#Start BPR Configs
Appearance_stuff() {

    local RC=0

    so_turnoff=''
    for so_name in 'dotglob' 'nullglob'
    do
        word_invert=''
        shopt -q $so_name;so_RC=$?
        if [ $so_RC -ne 0 ]
        then
            so_turnoff=${so_turnoff}','$so_name
            word_invert=' NOT '
        fi
        echo $so_name' is '${word_invert}'(Normally) set' >&2
        shopt -s $so_name
    done
    if [ $Refresh_git == 'Y' ]
    then
        cd $DOWNLOADS
        git clone https://github.com/bpr97050/FRITAdot.git
        Frita_download=${DOWNLOADS}/FRITAdot
        rm -rf ${Frita_download}/.git
        cd $Frita_download || return 8
        sudo rsync -aRv . /etc/skel
        cd
        rm -rf $Frita_download
    fi
    #Set LightDM wallpaper
    sudo sed -i 's/background=/#background=/g' /etc/lightdm/lightdm-gtk-greeter.conf
    sudo echo "background=#FFFFFF" >> /etc/lightdm/lightdm-gtk-greeter.conf
    
    so_turnoff_proper=$(echo $so_turnoff |sed -e 's/^,//')
    OLDIFS=$IFS
    IFS=$','
    for so_name in $so_turnoff
    do
        if [ ! -z "$so_name" ]
        then
            echo 'Turning off' $so_name >&2
            shopt -u $so_name
        fi
    done
    IFS=$OLDIFS
    shopt |grep 'on' >&2

    return $RC
}

Chromium_stuff() {

    local RC=0
    if [ "${Refresh_apt}." == 'Y.' ]
    then
        sudo apt-get install chromium-browser
        if [ $Refresh_git == 'Y' ]
        then
            #Pepperflash/Multimedia codecs installer
            wget -O check https://gist.githubusercontent.com/bpr97050/9899740/raw
            sudo mv check /usr/local/bin/
            sudo chmod +x /usr/local/bin/check

            wget -O master_preferences\
                https://gist.githubusercontent.com/bpr97050/a714210a8759b7ccc89c/raw/\
                   && sudo mv master_preferences /etc/chromium-browser/

            #Bookmarks
            wget -O default_bookmarks.html https://gist.github.com/bpr97050/b6b5679f94d344879328/raw && sudo mv default_bookmarks.html /etc/chromium-browser
            sudo add-apt-repository ppa:skunk/pepper-flash /etc/chromium-browser/master_preferences
        fi
    fi
    #Chromium Flags
    sudo sed -i 's/CHROMIUM_FLAGS=""/CHROMIUM_FLAGS="--start-maximized\
        --disable-new-tab-first-run --no-first-run\
        --disable-google-now-integration"/g' /etc/chromium-browser/default

    return $RC
}

Apt_stuff() {

    local RC=0
    sudo apt-get update
    sudo apt-get install git
    #Auto security upgrades
    sudo dpkg-reconfigure -plow unattended-upgrades
    #Remove unnecessary programs
    sudo apt-get purge --auto-remove ace-of-penguins abiword abiword-common libabiword-3.0 gnumeric gnumeric-common
    #Printing
    sudo apt-get install system-config-printer-gnome libprinterconf-dev
    #Replace Sylpheed with Claws Mail (looks similar to Outlook, more feature complete like Outlook)
    sudo apt-get purge --auto-remove sylpheed\
       && sudo apt-get install claws-mail claws-mail-extra-plugins claws-mail-tools claws-mail-plugins
    #Music (replace Audacious with Rhythmbox for Ipod support)
    sudo apt-get purge --auto-remove audacious\
        && sudo apt-get install libimobiledevice4 rhythmbox rhythmbox-plugins
    #Replace Mplayer with VLC (VLC seems to be more user friendly and less buggy)
    sudo apt-get purge --auto-remove gnome-mplayer && sudo apt-get install vlc
    #Wine stuff in case the user needs to run a Windows executable
    #udo apt-get install wine winetricks
    #Upgrade to Trusty
    #sudo do-release-upgrade
    # NOT! Messes with keyboard! Remove Ibus
    #sudo apt-get purge --auto-remove ibus

    return $RC
}

Pauze 'Start custom code' 'BEN Apt_stuff (cond)' $Refresh_apt

if [ "${Refresh_apt}." == 'Y.' ]
then
    Apt_stuff $@ || echo 'Apt?'
fi

Pauze 'BEN Apt_stuff (cond)' 'BEN Appearance_stuff (partly cond)' $Refresh_git

Appearance_stuff || echo 'Appearance?'

Pauze 'BEN Appearance_stuff (partly cond)' 'Ben Chromium_stuff (partly cond)' $Refresh_apt ' ' $Refresh_git

Chromium_stuff || echo 'Chromium Config?'

sudo apt-get --purge autoremove
sudo apt-get autoclean

Pauze 'Finished with BEN custom code. last RC:' 'Continue...' $?

#Only notify about LTS starting July 24th
#https://help.ubuntu.com/community/PreciseUpgrades
#End BPR Configs

