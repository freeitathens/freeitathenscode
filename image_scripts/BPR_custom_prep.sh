#!/bin/bash
set -u

custom_dotfiles_id='FRITAdot'
declare -r uri_desktop_files=\
'https://github.com/bpr97050/'${custom_dotfiles_id}'.git'

declare -r uri_chromium_mastprefs=\
'https://gist.githubusercontent.com/bpr97050/a714210a8759b7ccc89c/raw/'
dirname_sys_chromium='/etc/chromium-browser'

declare -r uri_chromium_bookmarks=\
'https://gist.github.com/bpr97050/b6b5679f94d344879328/raw'
filename_chromium_bookmarks='default_bookmarks.html'

file_chromium_defaults='default'
declare -r filepath_sys_chromium_defaults=\
"${dirname_sys_chromium}/$file_chromium_defaults"

declare -r uri_pepperflash_codex_installer=\
'https://gist.githubusercontent.com/bpr97050/9899740/raw'

declare -r uri_firefox_prefs=\
'https://gist.github.com/bpr97050/eb37e9850e2d951bc676/raw'
file_firefox_prefs='syspref.js'
sys_dir_firefox='/etc/firefox'
filepath_ff_prefs_sys="${sys_dir_firefox}/$file_firefox_prefs"

#TODO: Following link is broken (HTTP 404)
declare -r uri_firefox_bookmarks='http://a.pomf.se/kyiput.sqlite'

[[ -z $live_run ]] && live_run='N'
[[ -z $refresh_git ]] && refresh_git='N'
[[ -z $codebase ]] && codebase="${HOME}/freeitathenscode/image_scripts"
source /home/oem/freeitathenscode/image_scripts/Prepare_functions || exit 99

Mainline() {

    DOWNLOADS="/home/$(id -n -u)/Downloads"
    Pre_Verify_Downloads_dir

    Run_apt_update || return $?

    Download_custom_desktop_files\
        || echo 'Download_custom_desktop_files: Problem?'

    Firefox_stuff || echo 'Firefox Config: Problem?'
    Chromium_stuff || echo 'Chromium Config: Problem?'

    Set_backgrounds

    # -*- Auto security upgrades -*-
    [[ $live_run == 'Y' ]] &&\
        sudo dpkg-reconfigure -plow unattended-upgrades

    # -*- Install / update patches now -*-
    Prompt_time "apt-get dist-upgrade"
    sudo apt-get dist-upgrade

    Prompt_time 'apt-get purge autoremove and autoclean'
    sudo apt-get --purge autoremove
    sudo apt-get autoclean

    Post_Verify_Downloads_dir
    Prompt_time "Finished with BPR custom code. last RC: $?"

    return 0
}

Download_custom_desktop_files() {

    local RC=0

    cd $DOWNLOADS
    if [[ -d $custom_dotfiles_id ]]
    then
        rm -rf ${custom_dotfiles_id}/* ||RC=$?
    else
        mkdir $custom_dotfiles_id ||RC=$?
    fi
    if [ $RC -gt 0 ];then cd -;return $RC;fi

    if [[ $refresh_git != 'Y' ]]
    then
	cd -
	return 0
    fi

    cd $custom_dotfiles_id ||RC=$?
    if [ $RC -gt 0 ];then cd -;return $RC;fi

    Activate_shopts
    git clone $uri_desktop_files ||RC=$?
    if [ $RC -gt 0 ]
    then
	Reset_shopts
	cd -
	return $RC
    fi

    (echo -e "Sample Contents in $PWD\n";\
	find . -type f -exec head -n4 {} \;)|\
	od -Ax -taz |less
    Prompt_time "Now do Manual Moves (where appropriate) to /etc/skel/"
    #bash ||RC=$?

    Reset_shopts
    cd -
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

    filepath_ff_prefs_src="${DOWNLOADS}/$file_firefox_prefs"
    wget -O $filepath_ff_prefs_src $uri_firefox_prefs

    if [[ $live_run != 'Y' ]]
    then
	Prompt_time 'DRY RUN: action would be "cp -iv '\
	    ${filepath_ff_prefs_src}' '$filepath_ff_prefs_sys'"'
        return 0
    fi

    Backup_and_Customize $filepath_ff_prefs_src $filepath_ff_prefs_sys;RC=$?
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
#wget -O ${DOWNLOADS}/places.sqlite $uri_firefox_bookmarks

Chromium_stuff() {

    local RC=0

    Prompt_time 'Ensure latest chromium-browser is installed'
    sudo apt-get install chromium-browser

    Chromium_master_pref
    Chromium_defaults
    Chromium_bookmarks
    Chromium_nonfree_codex_prep || echo 'Problem with nonfree codex installer?'

    return $RC
}

Chromium_master_pref() {

    local RC=0
    filename_mast_prefs='master_preferences'
    filepath_mast_prefs_src="${DOWNLOADS}/${filename_mast_prefs}"

    Prompt_time 'Install chromium master prefs. $live_run='\
	$live_run', $refresh_git='$refresh_git
    if [[ $refresh_git == 'Y' ]]
    then
        wget -O ${filepath_mast_prefs_src} $uri_chromium_mastprefs
	RC=$?
    fi

    filepath_mast_prefs_sys=${dirname_sys_chromium}/${filename_mast_prefs}
    if [[ $live_run != 'Y' ]]
    then
        Prompt_time 'DRY RUN: would normally exec: "cp -iv '\
	    $filepath_mast_prefs_src\
	    ' '$filepath_mast_prefs_sys'"'
        return 0
    fi

    Backup_and_Customize $filepath_mast_prefs_src $filepath_mast_prefs_sys ||RC=$?

    return $RC
}

Chromium_defaults() {

    echo 'Current Chromium flags:'
    grep 'CHROMIUM_FLAGS=' $filepath_sys_chromium_defaults
    grep -P 'CHROMIUM_FLAGS=.+--ssl-version-min=tls1' $filepath_sys_chromium_defaults;RCxCF=$?
    if [[ $RCxCF -eq 0 ]]
    then
        Prompt_time 'Chromium Flags (appear to be) Already Updated.'
	return 0
    fi

    if [[ $live_run != 'Y' ]]
    then
        Prompt_time 'DRY RUN: Not changing Chromium flags yet ... '
	return 0
    fi
    
    Prompt_time 'Behold! CHROMIUM_FLAGS! Preparing to edit in-place...'
    sudo perl -pi'.bak' -ne 's/^(CHROMIUM_FLAGS=".+)"/${1} --start-maximized --no-first-run --ssl-version-min=tls1 --disable-google-now-integration"/;' $filepath_sys_chromium_defaults
    sudo mv -iv ${filepath_sys_chromium_defaults}.bak $HOME

    return $?
}

Chromium_bookmarks() {

    filepath_chromium_bookmarks_src="${DOWNLOADS}/$filename_chromium_bookmarks"
    filepath_chromium_bookmarks_sys="${dirname_sys_chromium}/$filename_chromium_bookmarks"
    wget -O $filepath_chromium_bookmarks_src $uri_chromium_bookmarks

    if [[ $live_run != 'Y' ]]
    then
	Prompt_time 'DRY RUN, live would do "cp -iv '\
	    $filepath_chromium_bookmarks_src\
	    $filepath_chromium_bookmarks_sys'"'
	return 0
    fi

    Backup_and_Customize $filepath_chromium_bookmarks_src $filepath_chromium_bookmarks_sys

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
	Prompt_time 'TODO: Make icon on desktop that runs /usr/local/bin/install_nonfree_codex'

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
	Prompt_time '/etc/mdm/conf: Set BackgroundColor in [ greeter ] stanza to #00e5a0'
    fi
    #sudo sed -i 's/^background=/#background=/g' /etc/lightdm/lightdm-gtk-greeter.conf
}

Backup_and_Customize() {
    local filepath_source=$1
    local filepath_target=$2

    filepath_diff=${filepath_diff_temp}'.diff'
    set -e
    if [ -f $filepath_target ]
    then
	cp -v --backup=t $filepath_target ${HOME}/
        diff $filepath_target $filepath_source\
	    >$filepath_diff
	[[ -s  $filepath_diff ]] || less $filepath_diff
    fi
    sudo cp -iv $filepath_source $filepath_target

    return $?
}

Pre_Verify_Downloads_dir() {

    [[ -d ${DOWNLOADS} ]] || mkdir $DOWNLOADS
    [[ -d ${DOWNLOADS} ]] || exit 13

    cd $DOWNLOADS || exit 14
    find $DOWNLOADS -not -uid $UID -exec sudo chown -c $UID {} \;
    echo -e "\n\n"
    find ${DOWNLOADS} -type f
    echo 'Downloaded files previous run (above).'
    Prompt_time 'Confirm or CONTROL-C'

}

Post_Verify_Downloads_dir() {

    find $DOWNLOADS -not -uid $UID -exec sudo chown -c $UID {} \;
    echo -e "\n\n"
    find ${DOWNLOADS} -type f -cmin -12
    echo 'Downloaded files this run (above).'
    Prompt_time 'Confirm or CONTROL-C'

}

timeout=12
Prompt_time() {
    mess=$@
    local RC=0

    echo -e "\e[1;32;40m"
    read -t$timeout -p"$mess <ENTER>";RC=$?
    echo -e "\e[0m"

    return $RC
}

filepath_diff_temp=$(mktemp -t prepare.XXX) || exit 99

Mainline

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
    #Pause_n_Answer 'Y|N' 'WARN,Customize Default Settings?'
    Prompt_time "HaVe A nIcE dAy"
