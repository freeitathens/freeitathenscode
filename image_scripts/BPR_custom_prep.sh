#!/bin/bash
set -u
declare -r HOLDIFS=$IFS 2>/dev/null

Mainline() {

    Run_apt_update || return $?

    DOWNLOADS=${HOME}/Downloads
    [[ -d ${DOWNLOADS} ]] || mkdir ${HOME}/Downloads
    [[ -d ${DOWNLOADS} ]] || exit 13

    Answer='N'
    Pause_n_Answer 'Y|N(default='$Answer')' 'WARN,Firefox custom config'
    [[ "${Answer}." == 'Y.' ]] && (Firefox_stuff || echo 'Firefox Config?')
    Chromium_stuff || echo 'Chromium Config?'

    Pauze 'refresh_git? '${refresh_git}
    [[ $refresh_git == 'Y' ]] && (Configs_from_github || echo 'Configs_from_github?')

    #Set LightDM wallpaper
    Set_backgrounds

    #Auto security upgrades
    Pauze 'Offer dpkg auto non-harmful upgrades'
    sudo dpkg-reconfigure -plow unattended-upgrades

    Pauze 'apt-get purge autoremove and autoclean'
    sudo apt-get --purge autoremove
    sudo apt-get autoclean

    Pauze "INFO,Finished with BPR custom code. last RC: $?"

    return 0
}

Firefox_stuff() {

    local RC=0

    apt-get install firefox || return 16

    # *--* Poodle et.al.,cf.https://addons.mozilla.org/en-US/firefox/addon/ssl-version-control/
    # Options for Firefox bookmarks and settings
    Answer='N'
    Pause_n_Answer 'Y|N' 'INFO,Install default settings for Firefox?'
    if [ "${Answer}." == 'Y.' ]
    then
        cd $DOWNLOADS
        wget -O syspref.js https://gist.github.com/bpr97050/eb37e9850e2d951bc676/raw
        mv syspref.js /etc/firefox/syspref.js
        #wget -O places.sqlite http://a.pomf.se/kyiput.sqlite
        timeout -k 1m 5s firefox
        #rm -iv ${HOME}/.mozilla/firefox/*.default/places.sqlite{,-*} 
        #mv places.sqlite ${HOME}/.mozilla/firefox/*.default/places.sqlite
        cd -
    fi

    return $RC
}

Chromium_stuff() {

    local RC=0

    sudo apt-get install chromium-browser

    # Ensure "/etc/chromium-browser" is a directory (not a file)
    [[ -e /etc/chromium-browser ]]\
        && ( [[ -d /etc/chromium-browser ]] || sudo mv -iv /etc/chromium-browser /tmp/ )
    [[ -d /etc/chromium-browser ]] || sudo mkdir /etc/chromium-browser

    Chromium_master_pref

    Chromium_defaults

    Chromium_bookmarks

    Chromium_prep_setup

    #sudo add-apt-repository ppa:skunk/pepper-flash
    #sudo apt-get install pepflashplugin-installer\
    #   && echo '. /usr/lib/pepflashplugin-installer/pepflashplayer.sh'\
    #   |sudo tee -a /etc/chromium-browser/default

    return $RC
}

Chromium_master_pref() {
    Answer='N'
    Pause_n_Answer 'Y|N' 'Git-Load Chromium Master Preferences?'
    if [ $Answer == 'Y' ]
    then
        cd $DOWNLOADS
        # Download master_preferences config file for chromium
        wget -O master_preferences\
            https://gist.githubusercontent.com/bpr97050/a714210a8759b7ccc89c/raw/\
            && sudo cp -iv master_preferences /etc/chromium-browser/
        cd -
    fi

    return $?
}

Chromium_defaults() {
    Answer='N'
    Pause_n_Answer 'Y|N' 'Set chrome defaults?'
    # *--* Poodle fix et.al. cf. https://disablessl3.com/ *--*
    if [ $Answer == 'Y' ]
    then
        # Ensure certain Chromium Flags settings are in place.
        sudo sed -i 's/CHROMIUM_FLAGS=""/CHROMIUM_FLAGS="--start-maximized\
            --disable-new-tab-first-run --no-first-run --ssl-version-min=tls1\
            --disable-google-now-integration"/g' /etc/chromium-browser/default
    fi

    return $?
}

Chromium_bookmarks() {
    Answer='N'
    Pause_n_Answer 'Y|N' 'Git-Load default_bookmarks.html?'
    if [ $Answer == 'Y' ]
    then
        cd $DOWNLOADS
        # Download default bookmarks for Chromium
        wget -O default_bookmarks.html\
            https://gist.github.com/bpr97050/b6b5679f94d344879328/raw\
            && sudo cp -iv default_bookmarks.html /etc/chromium-browser/
        cd -
    fi
}

Chromium_prep_setup() {

    Answer='N'
    Pause_n_Answer 'Y|N' 'Git-Load one-time Proprietary setup script?'
    [[ $Answer == 'Y' ]] || return 0

    cd $DOWNLOADS
    check_install_RC=1
    #Pepperflash/Multimedia codecs installer
    wget -O check https://gist.githubusercontent.com/bpr97050/9899740/raw\
        && sudo mv check /usr/local/bin/\
        && sudo chmod +x /usr/local/bin/check\
        && check_install_RC=0
    [[ $check_install_RC -eq 0 ]] || return $check_install_RC

    Answer='N'
    Pause_n_Answer 'Y|N' 'WARN,Setup firstboot option to offer non-free Multimedia?'
    [[ "${Answer}." == 'Y.' ]] || return 0

    Mess='non-free Multimedia install '
    tackon='OK'
    #sudo /usr/local/bin/check || tackon='NOT OK'
    #Pauze "$Mess$tackon"
    Pauze 'Make icon on desktop that runs /usr/bin/check'
    cd -

    return 0
}

Configs_from_github() {
    local RC=0
    Pauze 'BPR Configs_from_github'

    Activate_shopts

    Git_name=FRITAdot
    cd $DOWNLOADS || RC=$?
    [[ $RC -eq 0 ]]\
        && ( rm -rf ${Git_name}/ 2>/dev/null\
        && git clone https://github.com/bpr97050/${Git_name}.git || RC=$? )

    [[ $RC -eq 0 ]]\
        && ( sudo rsync -aRv --exclude '.git' --delete-excluded\
        ${Git_name}/\
        /etc/skel || RC=$? )
    cd -

    Reset_shopts
    return $RC
}

Activate_shopts() {
    orig_shopt_nullglob=$(shopt -p nullglob)
    orig_shopt_dotglob=$(shopt -p dotglob)
    shopt -s nullglob
    shopt -s dotglob
}

Reset_shopts() {
    [[ $orig_shopt_nullglob =~ ' -u ' ]] && shopt -u nullglob
    [[ $orig_shopt_dotglob =~ ' -u ' ]] && shopt -u dotglob
}

Set_backgrounds() {
    if [ -d /etc/lightdm/ ]
    then
	for greetings in $(find /etc/lightdm/ -mindepth 1 -maxdepth 1 -type f -name 'lightdm-gtk-greeter*')
	do
            Answer='N'
            Pause_n_Answer 'Y|N' 'INFO,reset background in '$greetings'?'
            if [ "${Answer}." == 'Y.' ]
            then 
		sudo sed -i 's/^background=/#background=/g' $greetings
		echo "background=#88ff00" | sudo tee -a $greetings
            fi
	done
    elif [ -d /etc/mdm/ ]
    then
	Pauze '/etc/mdm/conf: Set BackgroundColor in [ greeter ] stanza to #00e5a0'
    fi
    #sudo sed -i 's/^background=/#background=/g' /etc/lightdm/lightdm-gtk-greeter.conf
}

[[ -z $codebase ]] && codebase="${HOME}/freeitathenscode/image_scripts"
source ${codebase}/Common_functions || exit 12

Mainline

#Wine stuff in case the user needs to run a Windows executable
#sudo apt-get install wine winetricks
#sudo do-release-upgrade
#sudo apt-get install ibus

