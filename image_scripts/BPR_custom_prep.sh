#!/bin/bash
set -u
Git_name=FRITAdot
declare -r uri_desktop_files=\
'https://github.com/bpr97050/'${Git_name}'.git'
declare -r uri_chromium_prefs=\
'https://gist.githubusercontent.com/bpr97050/a714210a8759b7ccc89c/raw/'
#TO : /etc/chromium-browser/master_preferences 

declare -r uri_chromium_bookmarks=\
'https://gist.github.com/bpr97050/b6b5679f94d344879328/raw'
#TO : /etc/chromium-browser/default_bookmarks.html
declare -r chromium_default_settings='/etc/chromium-browser/default'

declare -r uri_pepperflash_codex_installer=\
'https://gist.githubusercontent.com/bpr97050/9899740/raw'

declare -r uri_firefox_prefs=\
'https://gist.github.com/bpr97050/eb37e9850e2d951bc676/raw'
#TO : /etc/firefox/syspref.js/syspref.js

#TODO: Following link is broken (HTTP 404)
declare -r uri_firefox_bookmarks='http://a.pomf.se/kyiput.sqlite'
[[ -z $live_run ]] && live_run='N'
[[ -z $refresh_git ]] && refresh_git='N'
[[ -z $codebase ]] && codebase="${HOME}/freeitathenscode/image_scripts"

Mainline() {

    Run_apt_update || return $?

    if [ $refresh_git == 'Y' ]
    then
        Download_custom_desktop_files\
            || echo 'Download_custom_desktop_files: Problem?'
    else
        Pauze 'Refresh from github not in the cards this run...'
    fi

    Firefox_stuff || echo 'Firefox Config: Problem?'
    Chromium_stuff || echo 'Chromium Config: Problem?'

    Set_backgrounds

    # -*- Auto security upgrades -*-
    [[ $live_run == 'Y' ]] &&\
	sudo dpkg-reconfigure -plow unattended-upgrades

    # -*- Install / update patches now -*-
    Pauze 'apt-get dist-upgrade'
    sudo apt-get dist-upgrade
    Pauze 'apt-get purge autoremove and autoclean'
    sudo apt-get --purge autoremove
    sudo apt-get autoclean

    Pauze "INFO,Finished with BPR custom code. last RC: $?"
    return 0
}

Download_custom_desktop_files() {

    local RC=0
    Pauze 'BPR Download_custom_desktop_files'
    cd $DOWNLOADS

    Activate_shopts
    [[ -n $Git_name ]] && [[ -d $Git_name ]] && sudo rm -rf ${Git_name}
    git clone $uri_desktop_files || return $?
    cd -

    find ${PWD}/${Git_name} -type f -exec head -n4 {} \;
    Pauze 'Now do Manual Moves from '${PWD}/${Git_name}' to /etc/skel/'
    bash
    #Broken: sudo rsync -aRv --exclude '.git' --delete-excluded ${Git_name}/ /etc/skel/
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

Firefox_stuff() {

    local RC=0

    sudo apt-get install firefox || return 16

    # *--* Poodle et.al.,
    #   cf.https://addons.mozilla.org/en-US/firefox/addon/ssl-version-control/
    # Options for Firefox bookmarks and settings
    wget -O ${DOWNLOADS}/syspref.js $uri_firefox_prefs
    #wget -O ${DOWNLOADS}/places.sqlite $uri_firefox_bookmarks

    Answer='N'
    [[ $live_run == 'Y' ]] &&\
        Pause_n_Answer 'Y|N' 'INFO,Customize Default Settings for Firefox?'
    if [ "${Answer}." == 'Y.' ]
    then
        sudo cp -iv ${DOWNLOADS}/syspref.js /etc/firefox/syspref.js ||RC=$?
        #rm -iv ${HOME}/.mozilla/firefox/*.default/places.sqlite{,-*} 
        #cp -iv ${DOWNLOADS}/places.sqlite ${HOME}/.mozilla/firefox/*.default/places.sqlite
        timeout -k 1m 5s firefox
    else
        Pauze 'DRY RUN?: action is cp -iv '${DOWNLOADS}'/syspref.js /etc/firefox/syspref.js'
    fi

    return $RC
}

Chromium_stuff() {

    local RC=0

    Pauze 'Ensure latest chromium-browser is installed'
    sudo apt-get install chromium-browser

    # Ensure "/etc/chromium-browser" is a directory (not a file)
    [[ -e /etc/chromium-browser ]]\
        && ( [[ -d /etc/chromium-browser ]]\
        || sudo mv -iv /etc/chromium-browser /tmp/ )
    [[ -d /etc/chromium-browser ]] || sudo mkdir /etc/chromium-browser

    [[ $refresh_git == 'Y' ]] && Chromium_master_pref
    Chromium_defaults
    Chromium_bookmarks
    Chromium_nonfree_codex_prep

    return $RC
}

Chromium_master_pref() {

    # Download master_preferences config file for chromium
    Pauze 'Download and install chromium master prefs'

    wget -O ${DOWNLOADS}/master_preferences $uri_chromium_prefs || return $?

    if [[ $live_run == 'Y' ]]
    then
        sudo cp -iv ${DOWNLOADS}/master_preferences /etc/chromium-browser/
    else
        Pauze 'DRY RUN: cp -iv '${DOWNLOADS}'/master_preferences /etc/chromium-browser/'
    fi

    return $?
}
#Answer='N'
#Pause_n_Answer 'Y|N' 'Git-Load Chromium Master Preferences?'

Chromium_defaults() {

    # Ensure certain Chromium Flags settings are in place.
    if [[ $live_run == 'Y' ]]
    then

sudo rm -f /tmp/chromium_flags
grep 'CHROMIUM_FLAGS' /etc/chromium-browser/default |grep -v '\$CHROMIUM_FLAGS' |perl -ne 'chomp;$cfl=$_;$cfl =~ s/^\s+//;print $cfl."\n";' |tee /tmp/chromium_flags
source /tmp/chromium_flags
echo $CHROMIUM_FLAGS 
Pauze 'Setup Chromium Flags (Append to above)'
    CHROMIUM_FLAGS=${CHROMIUM_FLAGS}' --start-maximized --disable-new-tab-first-run --no-first-run --ssl-version-min=tls1 --disable-google-now-integration'
    echo 'CHROMIUM_FLAGS='$CHROMIUM_FLAGS >>$chromium_default_settings
    vim $chromium_default_settings

    else
        Pauze 'DRY RUN: '
    fi

    return $?
    # *--* Poodle fix et.al. cf. https://disablessl3.com/ *--*
}

Chromium_bookmarks() {

    wget -O ${DOWNLOADS}/default_bookmarks.html $uri_chromium_bookmarks
    if [[ $live_run == 'Y' ]]
    then
        sudo cp -iv\
            ${DOWNLOADS}/default_bookmarks.html /etc/chromium-browser/
    else
        Pauze 'DRY RUN: copy '${DOWNLOADS}'/default_bookmarks.html /etc/chromium-browser/'
    fi

    return $?
}

Chromium_nonfree_codex_prep() {

    RCxPSS=1
    #Pepperflash/Multimedia codecs installer
    wget -O ${DOWNLOADS}/install_nonfree_codex ${uri_pepperflash_codex_installer}\
        && sudo cp -iv ${DOWNLOADS}/install_nonfree_codex /usr/local/bin/\
        && sudo chmod +x /usr/local/bin/install_nonfree_codex\
        && RCxPSS=0

    [[ $RCxPSS -eq 0 ]] &&\
    Pauze 'Make icon on desktop that runs /usr/local/bin/install_nonfree_codex'

    return $RCxPSS
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

declare -r HOLDIFS=$IFS 2>/dev/null
source ${codebase}/Common_functions || exit 12
source ${codebase}/Prepare_functions || exit 13

DOWNLOADS=${HOME}'/Downloads'
[[ -d ${DOWNLOADS} ]] || mkdir ${HOME}/Downloads
[[ -d ${DOWNLOADS} ]] || exit 13

echo $DOWNLOADS
Pauze 'Confirm above is Downloads'

find $DOWNLOADS -not -uid $UID -exec sudo chown -c $UID {} \;
Mainline

find $DOWNLOADS -not -uid $UID -exec sudo chown -c $UID {} \;
Pauze 'Downloaded files this run:'
find ${DOWNLOADS} -cmin -12

#Wine stuff in case the user needs to run a Windows executable
#sudo apt-get install wine winetricks
#sudo do-release-upgrade
#sudo apt-get install ibus
   #     sudo sed -i 's/CHROMIUM_FLAGS=""/CHROMIUM_FLAGS="--start-maximized\
   #     --disable-new-tab-first-run --no-first-run --ssl-version-min=tls1\
   #     --disable-google-now-integration"/g' /etc/chromium-browser/default

    #sudo add-apt-repository ppa:skunk/pepper-flash
    #sudo apt-get install pepflashplugin-installer\
    #   && echo '. /usr/lib/pepflashplugin-installer/pepflashplayer.sh'\
    #   |sudo tee -a /etc/chromium-browser/default

