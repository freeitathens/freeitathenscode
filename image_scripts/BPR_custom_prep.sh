#!/bin/bash
set -u
timeout=12

custom_dotfiles_id='FRITAdot'
declare -r uri_desktop_files=\
'https://github.com/bpr97050/'${custom_dotfiles_id}'.git'

declare -r uri_chromium_mastprefs=\
'https://gist.githubusercontent.com/bpr97050/a714210a8759b7ccc89c/raw/'
sys_dir_chromium='/etc/chromium-browser'

declare -r uri_chromium_bookmarks=\
'https://gist.github.com/bpr97050/b6b5679f94d344879328/raw'
file_chromium_bookmarks='default_bookmarks.html'

file_chromium_defaults='default'
declare -r sys_path_chromium_defaults=\
"${sys_dir_chromium}/$file_chromium_defaults"

declare -r uri_pepperflash_codex_installer=\
'https://gist.githubusercontent.com/bpr97050/9899740/raw'

declare -r uri_firefox_prefs=\
'https://gist.github.com/bpr97050/eb37e9850e2d951bc676/raw'
file_firefox_prefs='syspref.js'
sys_dir_firefox='/etc/firefox'
sys_path_firefox_prefs="${sys_dir_firefox}/$file_firefox_prefs"

#TODO: Following link is broken (HTTP 404)
declare -r uri_firefox_bookmarks='http://a.pomf.se/kyiput.sqlite'

[[ -z $live_run ]] && live_run='N'
[[ -z $refresh_git ]] && refresh_git='N'
[[ -z $codebase ]] && codebase="${HOME}/freeitathenscode/image_scripts"

Mainline() {

    Run_apt_update || return $?

    cd $DOWNLOADS
    Download_custom_desktop_files\
        || echo 'Download_custom_desktop_files: Problem?'
    cd -

    Firefox_stuff || echo 'Firefox Config: Problem?'
    Chromium_stuff || echo 'Chromium Config: Problem?'

    Set_backgrounds

    # -*- Auto security upgrades -*-
    [[ $live_run == 'Y' ]] &&\
        sudo dpkg-reconfigure -plow unattended-upgrades

    # -*- Install / update patches now -*-
    read -t$timeout -p'apt-get dist-upgrade'
    sudo apt-get dist-upgrade
    read -t$timeout -p'apt-get purge autoremove and autoclean'
    sudo apt-get --purge autoremove
    sudo apt-get autoclean

    read -t$timeout -p'Finished with BPR custom code. last RC: '$?

    return 0
}

Download_custom_desktop_files() {

    local RC=0

    Activate_shopts
    if [[ -d $custom_dotfiles_id ]]
    then
        rm -rf ${custom_dotfiles_id}/*
    else
        mkdir $custom_dotfiles_id
    fi

    [[ $refresh_git == 'Y' ]] || return 0

    cd $custom_dotfiles_id || return 12
    git clone $uri_desktop_files || return $?
    find . -type f -exec head -n4 {} \;

    read -t$timeout -p'Now do Manual Moves (where appropriate) to /etc/skel/'
    #bash ||RC=$?
    Reset_shopts

    return $RC
}

Activate_shopts() {

    shopt -o >&2
    orig_shopt_nullglob=$(shopt -p nullglob)
    orig_shopt_dotglob=$(shopt -p dotglob)
    shopt -s nullglob
    shopt -s dotglob

    return $?
}

Reset_shopts() {

    [[ $orig_shopt_nullglob =~ ' -u ' ]] && shopt -u nullglob
    [[ $orig_shopt_dotglob =~ ' -u ' ]] && shopt -u dotglob
    shopt -o >&2

    return $?
}

Firefox_stuff() {

    local RC=0

    #sudo apt-get install firefox || return 16
    which firefox || return 16

    src_path_firefox_prefs="${DOWNLOADS}/$file_firefox_prefs"
    # Options for Firefox bookmarks and settings
    wget -O $src_path_firefox_prefs $uri_firefox_prefs
    #wget -O ${DOWNLOADS}/places.sqlite $uri_firefox_bookmarks

    if [[ $live_run != 'Y' ]]
    then
        read -t$timeout -p'DRY RUN: action would be "cp -iv '${src_path_firefox_prefs}' '$sys_path_firefox_prefs'"'
        return 0
    fi

    Answer='N'
    diff $sys_path_firefox_prefs $src_path_firefox_prefs |less
    Pause_n_Answer 'Y|N' 'WARN,Customize Default Settings for Firefox?'
    if [[ "${Answer}." == 'Y.' ]]
    then
        cp -iv --backup=t $sys_path_firefox_prefs ${HOME}/ 2>/dev/null
        sudo cp -iv ${src_path_firefox_prefs} $sys_path_firefox_prefs
        RC=$?
    fi 
    [[ $RC -eq 0 ]] && timeout -k 1m 5s firefox

    return $RC
}
# *--* Poodle fixes, et.al.:
# cf. https://addons.mozilla.org/en-US/firefox/addon/ssl-version-control/
# cf. https://disablessl3.com/ *--*

#TODO sql code to merge sqlite bookmarks (places)
#rm -iv ${HOME}/.mozilla/firefox/*.default/places.sqlite{,-*} 
#cp -iv ${DOWNLOADS}/places.sqlite
#    ${HOME}/.mozilla/firefox/*.default/places.sqlite

Chromium_stuff() {

    local RC=0

    read -t$timeout -p'Ensure latest chromium-browser is installed'
    sudo apt-get install chromium-browser

    Chromium_master_pref
    Chromium_defaults
    Chromium_bookmarks
    Chromium_nonfree_codex_prep || echo 'Problem with nonfree codex installer?'

    return $RC
}

Chromium_master_pref() {

    local RC=0

    file_mastprefs='master_preferences'
    src_path_mastprefs="${DOWNLOADS}/${file_mastprefs}"
    read -t$timeout -p'Install chromium master prefs. $live_run='$live_run', $refresh_git='$refresh_git
    if [[ $refresh_git == 'Y' ]]
    then
        wget -O ${src_path_mastprefs} $uri_chromium_mastprefs
	RC=$?
    fi

    if [[ $live_run != 'Y' ]]
    then
        read -t$timeout -p'DRY RUN: would normally exec: cp -iv '$src_path_mastprefs' '$sys_dir_chromium'/'
        return 0
    fi

    sys_path_mastprefs=${sys_dir_chromium}/${file_mastprefs}
    if [ -e $sys_path_mastprefs ]
    then
        diff $sys_path_mastprefs $src_path_mastprefs |less
    fi
    Answer='N'
    Pause_n_Answer 'Y|N' 'Install Custom Chromium Master Preferences?'
    if [[ "${Answer}." == 'Y.' ]]
    then
        cp -iv --backup=t $sys_path_mastprefs ${HOME}/ 2>/dev/null
        sudo cp -iv ${src_path_mastprefs} ${sys_dir_chromium}/ ||RC=$?
    fi

    return $RC
}

Chromium_defaults() {

    grep 'CHROMIUM_FLAGS' $sys_path_chromium_defaults
    CHROMIUM_ADD_FLAGS='--start-maximized --no-first-run --ssl-version-min=tls1 --disable-google-now-integration'
    echo 'Our Flags to add: '$CHROMIUM_ADD_FLAGS

    if [[ $live_run != 'Y' ]]
    then
        read -t$timeout -p'DRY RUN: Not changing Chromium flags yet ... '
	return 0
    fi
    
    read -t$timeout -p'<CONTINUE>'
    echo -n $CHROMIUM_ADD_FLAGS |\
        sudo perl -pi'.bak' -ne 'chomp;cf=$_;s/^(CHROMIUM_FLAGS='\''.+'\'')/${1} $cf'\''/;'

    return $?
}

Chromium_bookmarks() {

    sys_path_chromium_bookmarks="${sys_dir_chromium}/$file_chromium_bookmarks"
    src_path_chromium_bookmarks="${DOWNLOADS}/$file_chromium_bookmarks"
    diff ${sys_dir_chromium}/ $src_path_chromium_bookmarks
    if [[ $live_run != 'Y' ]]
    then
        read -t$timeout -p'DRY RUN, live would do "cp -iv '$src_path_chromium_bookmarks ${sys_dir_chromium}'/"'
	return 0
    fi

    wget -O $src_path_chromium_bookmarks $uri_chromium_bookmarks
    cp -iv --backup=t $sys_path_chromium_bookmarks ${HOME}/
    sudo cp -iv $src_path_chromium_bookmarks ${sys_dir_chromium}/

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
        read -t3 -p'Make icon on desktop that runs /usr/local/bin/install_nonfree_codex'

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
        read -t$timeout -p'/etc/mdm/conf: Set BackgroundColor in [ greeter ] stanza to #00e5a0'
    fi
    #sudo sed -i 's/^background=/#background=/g' /etc/lightdm/lightdm-gtk-greeter.conf
}

source /home/oem/freeitathenscode/image_scripts/Prepare_functions || exit 99

DOWNLOADS="/home/$(id -n -u)/Downloads"
[[ -d ${DOWNLOADS} ]] || mkdir $DOWNLOADS
[[ -d ${DOWNLOADS} ]] || exit 13

cd $DOWNLOADS
pwd
find $DOWNLOADS -not -uid $UID -exec sudo chown -c $UID {} \;
read -t$timeout -p'Confirm (above) is Downloads Directory and contents'
cd -

Mainline

find $DOWNLOADS -not -uid $UID -exec sudo chown -c $UID {} \;
find ${DOWNLOADS} -cmin -12
read -t$timeout -p'Downloaded files this run (above).'

#Wine stuff in case the user needs to run a Windows executable
#sudo apt-get install wine winetricks
#sudo do-release-upgrade
#sudo apt-get install ibus
   #     sudo sed -i 's/CHROMIUM_FLAGS=""/CHROMIUM_FLAGS="--start-maximized
   #     --disable-new-tab-first-run --no-first-run --ssl-version-min=tls1
   #     --disable-google-now-integration"/g' /etc/chromium-browser/default

    #sudo add-apt-repository ppa:skunk/pepper-flash
    #sudo apt-get install pepflashplugin-installer
    #   && echo '. /usr/lib/pepflashplugin-installer/pepflashplayer.sh'
#https://github.com/freeITathens/freeitathenscode/blob/master/image_scripts/BPR_xt_lubuntu_32bit.sh

