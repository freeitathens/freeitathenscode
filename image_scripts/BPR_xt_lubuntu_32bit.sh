#!/bin/bash
#Start BPR Configs
Refresh_Apt=${1:-'Y'}
shift

DOWNLOADS=${HOME}/Downloads
[[ -d ${DOWNLOADS} ]] || DOWNLOADS=/tmp

Appearance_stuff() {

    shopt -s dotglob nullglob
    local RC=0
    cd $DOWNLOADS
    git clone https://github.com/bpr97050/FRITAdot.git
    Frita_download=${DOWNLOADS}/FRITAdot
    rm -rf ${Frita_download}/.git
    cd $Frita_download || return 8
    sudo rsync -aRv . /etc/skel
    cd
    rm -rf $Frita_download
    #Set LightDM wallpaper
    sudo sed -i 's/background=/#background=/g' /etc/lightdm/lightdm-gtk-greeter.conf
    sudo echo "background=#FFFFFF" >> /etc/lightdm/lightdm-gtk-greeter.conf

    return $RC
}

Chromium_stuff() {

    local RC=0
    sudo apt-get install chromium-browser
    #Pepperflash/Multimedia codecs installer
    #   wget -O check https://gist.githubusercontent.com/bpr97050/9899740/raw
    #   sudo mv check /usr/local/bin/
    #   sudo chmod +x /usr/local/bin/check
    #   sudo add-apt-repository ppa:skunk/pepper-flash
    #/etc/chromium-browser/master_preferences
    wget -O master_preferences\
        https://gist.githubusercontent.com/bpr97050/a714210a8759b7ccc89c/raw/\
        && sudo mv master_preferences /etc/chromium-browser/
    #Bookmarks
    wget -O default_bookmarks.html https://gist.github.com/bpr97050/b6b5679f94d344879328/raw\
        && sudo mv default_bookmarks.html /etc/chromium-browser
    #Chromium Flags
    sudo sed -i 's/CHROMIUM_FLAGS=""/CHROMIUM_FLAGS="--start-maximized --disable-new-tab-first-run --no-first-run\
        --disable-google-now-integration"/g' /etc/chromium-browser/default

    return $RC
}

Apt_stuff() {

    local RC=0
    [[ "${Refresh_Apt}" == 'Y.' ]] && sudo apt-get update
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

Apt_stuff $@ || echo 'Apt?'
Appearance_stuff || echo 'Appearance?'
Chromium_stuff || echo 'Chromium Config?'

sudo apt-get --purge autoremove
sudo apt-get autoclean

#Only notify about LTS starting July 24th
#https://help.ubuntu.com/community/PreciseUpgrades
#End BPR Configs

