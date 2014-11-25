#!/bin/bash +x
[[ 0 -ne $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]] &&\
    read -p'NOTE: Permission Problems? Rerun with sudo (i.e., as root).<ENTER>' -t5

# Establish base of version-controlled code tree.
[[ -z $SOURCEBASE ]] && declare -x SOURCEBASE='/home/oem/freeitathenscode'
[[ -d $SOURCEBASE ]] || exit 25
# Establish location of these scripts within SOURCEBASE
codebase=${SOURCEBASE}'/image_scripts'
[[ -d $codebase ]] || exit 14

declare -x codebase
source ${codebase}/Prepare_functions || exit 136

package_list_path_I=${codebase}'/Packages'
wallpaper_filename='FreeIT.png'
wallpaper_source_pathname=${codebase}/$wallpaper_filename
wallpaper_system_dirname='/usr/share/backgrounds'
wallpaper_was_setup='N'

aptcache_needs_update='Y'
refresh_updatedb='N'
refresh_svn='N'
refresh_git='Y'
ADD_ALL='Y'
PUR_ALL='Y'
live_run='N'
Not_Batch_Run='N'

This_script=$(basename $0)
declare -rx Messages_O=$(mktemp -t "${This_script}_log.XXXXX")
declare -rx Errors_O=$(mktemp -t "${This_script}_err.XXXXX")
Optvalid='APBDn:RuVGh'

Mainline() {

    Housekeeping
    Integrity_check
    Install_Remove_requested_packages

    if [ $address_len -eq 64 ]
    then
        grep -o -P '^OnlyShowIn=.*MATE' /usr/share/applications/screensavers/*.desktop 
        Pauze 'Mate Desktop able to access xscreensavers for ant spotlight?'
    fi

    set -u
    Check_Setup_wallpaper;RCxW=$?
    Report_Check_Setup_wallpaper $RCxW
    set +u

    Pauze 'Lauching Virtual Greybeard'
    clear
    vrms
    Pauze '/\Please Purge Non-Free Stuff IF NEEDED/\'

    [[ $live_run == 'Y' ]] &&\
        Cleanup_nouser_nogroup ${HOME}'/Ran_nouser_nogroup_fix'

    return 0
}

Housekeeping() {

    sys_rpts_distro_name=''
    if [ -z $DISTRO_NAME ] 
    then
        Distro_name_Set;RCxDnS=$?
        if [ $RCxDnS -gt 0 ]
        then
            echo 'Distro_name_set ='$RCxDnS
            read -p'<ENTER>'
            No_distro_name_bye $RCxDnS
        else
            Pauze 'Good Selection!:'$DISTRO_NAME
        fi
    fi

    address_len=0
    Get_Address_Len
    Confirm_DISTRO_CPU || User_no_distro_bye $?

    [[ "${refresh_updatedb}." == 'Y.' ]] && updatedb &
    [[ "${refresh_svn}." == 'Y.' ]] && Contact_server

    Pauze 'Will update apt-metadata if requested (COND:'$aptcache_needs_update')'
    [[ $aptcache_needs_update == 'Y' ]] && Run_apt_update

    #Pauze 'Confirm no medibuntu in apt sources'
    #egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list

    return 0
}

Distro_name_Set() {

    Pauze 'No distro supplied in parms. (e.g., -d FRITAROX)...'
    Set_sys_rpts_distro_name;RCxS=$?
    [[ $RCxS -eq 0 ]] || return 30

    DISTRO_NAME=$sys_rpts_distro_name
    echo 'set' \$DISTRO_NAME '= '$DISTRO_NAME
    Answer='N'
    Pause_n_Answer 'Y|N' '...system value '${DISTRO_NAME}' is used, OK? '
    [[ "${Answer}." == 'Y.' ]] || return 12

    return 0
}

Set_Confirm_distro_name() {
    DISTRO_NAME=$1
    [[ -z $DISTRO_NAME ]] && return 40

    echo -e "\n\e[1;32;40mEvaluating your input: ${DISTRO_NAME}\n"
    read -p'<ENTER>' -t3

    Set_sys_rpts_distro_name;RCxS=$?
    if [ $RCxS -gt 0 ]
    then
        echo 'Cant confirm your distro name '\
            $DISTRO_NAME' against the system name(s)'
        read -p'<ENTER>' -t3
        return 2
    fi

    if [ "${DISTRO_NAME}." == "${sys_rpts_distro_name}." ]
    then
        echo 'System distro value ('${sys_rpts_distro_name}\
        ') agrees with your input ('${DISTRO_NAME}').'
        read -p'<ENTER>' -t3
        return 0
    fi

    echo 'System distro value ('\
        ${sys_rpts_distro_name}\
          '): mismatch (however slight) with input: ('\
        ${DISTRO_NAME}').'
    read -p'<ACCEPT(=Y)?>' -a ANS_ARR
    [[ ${#ANS_ARR[*]} -gt 0 ]] && [[ ${ANS_ARR[0]} == 'Y' ]] && DISTRO_NAME=$sys_rpts_distro_name && return 0

    return 3
}

Set_sys_rpts_distro_name() {

    sys_rpts_distro_name=$(lsb_release -a 2>/dev/null\
            |grep '^Distributor ID:'|cut -f2 -d:\
            |sed -e 's/^[ \t]*//')

    if [ -n ${sys_rpts_distro_name} ]
    then
        echo 'System reports distro as '${sys_rpts_distro_name}'.'
        read -p'<ENTER>'
        return 0
    fi

    # Try other methods
    if [ "${SESSION}." == 'Lubuntu.' ]
    then
        sys_rpts_distro_name=$SESSION
        echo 'Using session name '$sys_rpts_distro_name' as distribution.'
        read -p'<ENTER>' -t3
        return 0
    fi

    # Tell calling routing we can't system-set distro name.
    return 12
}

No_distro_name_bye() {
    local RCxDC=${1:-98}

    prettyprint '1,31,40,M,n' 'Cannot Set Distro name'
    Pauze 'Exiting....'

    exit $RCxDC
}

Confirm_DISTRO_CPU() {

    distro_valid_flag='?'
    prettyprint '1,32,40,M,0' $DISTRO_NAME' is'
    case $DISTRO_NAME in
    LinuxMint|mint)
        distro_generia='mint'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' ' a valid'
        ;;
    debian|SolydXK)
        distro_generia='debian'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' ' a valid'
        ;;
    lubuntu|Ubuntu)
        distro_generia='ubuntu'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' ' a valid'
        ;;
    redhat|slackware|SuSE|crunchbang)
        distro_generia='other'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' " a valid (but you're on your own...)"
        ;;
    *)
        distro_generia='LINUX_DISTRO_not_appearing_in_this_film_WARE'
        distro_valid_flag='N'
        prettyprint '1,31,40,M' ' an INVALID'
        ;;
    esac
    prettyprint '1,32,40,M,n' ' distribution name.'
    [[ $distro_valid_flag != 'Y' ]] && return 16

    prettyprint '0,1,32,40,M,n' 'Using general distro (category) name of '$distro_generia'.'
    Pauze "INFO,Confirmed $DISTRO_NAME on ${address_len}-bit box."

    return 0

}

User_no_distro_bye() {
    local RCxDC=${1:-99}

    prettyprint '5,31,47,M,n,0' 'No Known Distro Name, Exiting.'
    Pauze "See you back soon!"

    exit $RCxDC
}

Contact_server() {

    Pauze "Check that server address is correct and is contactable ( COND: $refresh_svn )"

    Sub_lcl_stat() {
        echo 'Check on subversion local repo status'
        if [ -d ${SOURCEBASE}/.svn ]
        then
            cd ${SOURCEBASE}/
            svn update
        else
            apt-get install subversion
            cd
            Correct_subversion_ssh
            svn co svn+ssh://frita@192.168.1.9/var/svn/Frita/freeitathenscode/
        fi
        Pauze '(DONE) Check on subversion local repo status'
    }

    [[ $(ssh frita@192.168.1.9 'echo $HOSTNAME') =~ 'nuvo-servo' ]]\
        && Pauze 'Checked Server is valid: 192.168.1.9' && Sub_lcl_stat && return $?

    return 1
}

Correct_subversion_ssh() {

    subv_conf=''
    for subversion_meta_dir in $(find '/home/'$(grep ':'$UID':' /etc/passwd |cut -f1 -d:) -maxdepth 1 -type d -name '.subversion';find /etc/ -maxdepth 1 -type d -name 'subversion')
    do
        subv_conf="${subversion_meta_dir}/config"
        echo 'Checking subversion config path '$subv_conf
        [[ -f ${subv_conf} ]] && break
        subv_conf=''
    done
    [[ -z $subv_conf ]] && return 4

    grep 'ssh' $subv_conf
    Answer='N'
    Pause_n_Answer 'Y|N' "Fix $subv_conf for Frita's ssh connection (Y|N)? "
    case $Answer in
        Y)
            sudo perl -pi'.bak' -e 's/#\s*ssh\b(.+?ssh)\s+-q(.+)$/ssh${1} -v${2}/' ${subv_conf}
            ;;
        *)
            Pauze 'OK, NO changes made...'
            ;;
    esac

    return 0
}

Integrity_check() {
    Pauze 'Check (absence of) local UUID reference for swap in fstab.'
    RCxU=1
    grep -P 'UUID.+swap' /etc/fstab && RCxU=$?
    if [ $RCxU -eq 0 ]
    then
        Pauze 'fstab cAnNoT gO oN iMaGe wItH lOcAl UUID reference. Entering editor...'
        sudo vi /etc/fstab
    fi

    Pauze 'Checking swap'
    Run_Cap_Out sudo swapoff --all --verbose
    Run_Cap_Out sudo swapon --all --verbose

    Pauze "Ensuring that QC.sh and revert_prep... are properly linked in ${HOME}/bin" 
    local_scripts_DIR="${HOME}/bin"
    [[ -d $local_scripts_DIR ]] || mkdir $local_scripts_DIR
    sudo chown -c oem $local_scripts_DIR

    [[ -e ${local_scripts_DIR}/QC.sh ]] || ln -s ${SOURCEBASE}/QC_Process/QC.sh ${local_scripts_DIR}/QC.sh
    [[ -e ${local_scripts_DIR}/revert_prep_for_shipping_to_eu ]]\
        || ln -s ${codebase}/revert_prep_for_shipping_to_eu ${local_scripts_DIR}/revert_prep_for_shipping_to_eu 
    find ${local_scripts_DIR} -ls
    echo ''

    Pauze 'Confirming that the correct Run Quality Control icon is in place...'
    (find ${SOURCEBASE}/QC_Process -iname 'Quality*' -exec md5sum {} \; ;\
        find ${SOURCEBASE}/QC_process_dev/Master_${address_len} -iname 'Quality*' -exec md5sum {} \; ;\
        find ${HOME}/Desktop -iname 'Quality*' -exec md5sum {} \;) |grep -v '\.svn' |sort
    echo ''

    Pauze 'Done with Integrity Check'

    return 0
}

Install_Remove_requested_packages() {

    case $distro_generia in
        mint)
            Pauze 'WARNING,Ensure backports in /etc/apt/sources.list (or sources.d/)' 
            ;;
        *)
            Pauze 'Assuming Backports are automatically included'
            ;;
    esac

    Pauze 'Install necessary packages'
    RCxPK=0
    Install_packages_from_file_list $package_list_path_I || RCxPK=$?
    [[ $RCxPK -ne 0 ]] && Pauze 'Problems Installing Packages:'$RCxPK

    case $distro_generia in
        ubuntu|mint)
            echo 'Run BPR Code'
            [[ -f ${codebase}/BPR_custom_prep.sh ]] &&\
                ${codebase}/BPR_custom_prep.sh
            Pauze "Run BPR: Last return code: $?"
            ;;
        *)
            Pauze "Don't need to run BPR additions for "$distro_generia' ('$DISTRO_NAME')'
            ;;
    esac

    return 0
}
#for pkg_file in $(find $This_script_dir -maxdepth 1 -type f -name 'Packages*')

Install_packages_from_file_list() {
    local package_list_file=$1
    RCz=0

    Process_package() {
        IFS=','
        declare -ra pkg_info_a=($1)
        IFS=$HOLDIFS

        declare -r pkg_info_L=${#pkg_info_a[*]}
        pkg_name=${pkg_info_a[0]}
        pkg_by_addr=${pkg_info_a[1]}
        [[ pkg_by_addr -eq 0 ]] && pkg_by_addr=$address_len
        if [ $pkg_by_addr != $address_len ]
        then
            echo 'Skipping package '$pkg_name' on '$address_len' box.'
            return 4
        fi

        RCxE=0
        [[ $pkg_info_L -gt 3 ]] && (Check_extra $pkg_name ${pkg_info_a[3]} || RCxE=$?)
        [[ $RCxE -gt 10 ]] && return $RCxE

        Pkg_by_distro_session ${pkg_info_a[2]};RCxDS=$?
    }
    for pkg_info_csv in $(grep -v '^#' $package_list_file)
    do
        Process_package $pkg_info_csv;RCa=$?
        if [ $RCa -gt 0 ]
        then
            echo 'Problem with package '$pkg_name
            ((RCz+=$RCa))
        fi 
    done
    return $RCz
}

Check_extra() {
    local pkg_name=$1
    shift 1
    pkg_extra=$@
    [[ -z $pkg_extra ]] && return 4

    IFS='\='
    declare -a extra_a=($pkg_extra)
    IFS=$HOLDIFS
    declare extra_L=${#extra_a[*]}
    [[ $extra_L -gt 1 ]] || return 5
    case ${extra_a[0]} in
        ppa)
            RCxPPA=0
            Establish_ppa_repo_sourcefile $pkg_name ${extra_a[1]}
            RCxPPA=$?
            [[ $RCxPPA -gt 10 ]] && return $RCxPPA
            if [ $RCxPPA -gt 0 ]
            then
                Pauze 'Return code for ppa setup ='$RCxPPA
                RCxPPA=0
            fi 
            return $RCxPPA
            ;;
        INSTALL)
            echo 'Check that '${extra_a[1]}' replaces '$pkg_name
            return 0
            ;;
        REMOVE)
            echo 'Check that '$pkg_name' replaces '${extra_a[1]}
            return 0
            ;;
        *)
            echo 'Unknown Extra Code:'$pkg_extra' for '$pkg_name
            return 60
            ;;
    esac

    return 115
}

Establish_ppa_repo_sourcefile() {
    local pkg_name=$1
    shift;ppa_name=$@

    search_ppa_name=$(echo $ppa_name|tr '/' '-')
    Pauze 'Beginning search for source.d ppa '$search_ppa_name'...'
    RCxRo=1
    find /etc/apt/sources.list.d/ -type f|grep $search_ppa_name && RCxRo=$?
    if [ $RCxRo -eq 0 ]
    then
        read -p'Found ppa, returning. <ENTER(t=8)>' -t8
        return 0
    fi
    apt_repo_name='ppa:'$ppa_name
    echo -n $apt_repo_name
    read -p' <Add to APT Repos?>' -a ADD_PPA_ARR || return 4
    [[ ${#ADD_PPA_ARR[*]} -eq 0 ]] && return 0
    if [ ${ADD_PPA_ARR[0]} == 'Y' ]
    then
        if [ $live_run != 'Y' ]
        then
            Pauze 'DRY RUN: adding repo '$apt_repo_name
            return 0
        fi

        sudo add-apt-repository $apt_repo_name || return $?
        return 0

    else
        Pauze 'Add repo '$apt_repo_name' later...'
        return 1
    fi

    return $?
}

Pkg_by_distro_session() {
    distro_session=$1

    Pkg_purge() {
       echo -n $pkg_name' '
       declare -a PUR_ARR=('Y')
       if [ $PUR_ALL == 'N' ]
       then
           read -p'<Purge?>' -a PUR_ARR || return $?
       fi
       [[ ${#PUR_ARR[*]} -eq 0 ]] && return 1
       if [ ${PUR_ARR[0]} == 'Y' ]
       then
           Apt_purge $pkg_name || return $?
       fi
   }
   Pkg_add() {
       echo -n $pkg_name' '
       declare -a ADD_ARR=('Y')
       if [ $ADD_ALL == 'N' ]
       then
           read -p'<Install/Upgrad3(Y|n)?>' -a ADD_ARR || return $?
       fi
       [[ ${#ADD_ARR[*]} -eq 0 ]] && return 1
       if [ ${ADD_ARR[0]} == 'Y' ]
       then
           Apt_install $pkg_name || return $?
       fi
   }
   case $distro_session in
       NONE)
           Pkg_purge ||return $?
           ;;
       ALL)
           Pkg_add || return $?
           ;;
       $distro_generia)
           Pkg_add || return $?
           ;;
   esac

   return 1
}

Check_Setup_wallpaper() {

    [[ $DISTRO_NAME == 'lubuntu' ]] && wallpaper_system_dirname='/usr/share/lubuntu/wallpapers'
    wallpaper_system_path=${wallpaper_system_dirname}/$wallpaper_filename
    if [[ -e $wallpaper_system_path ]]
    then
        wallpaper_was_setup='Y'
        return 0
    fi

    [[ -d $wallpaper_system_dirname ]] || return 5
    
    [[ -f $wallpaper_source_pathname ]] || return 6

    Answer='Y'
    Pause_n_Answer 'Y|N' 'INFO,Copy '$wallpaper_filename' to '$wallpaper_system_dirname'?'
    if [ "${Answer}." == 'Y.' ]
    then
        if [ $live_run != 'Y' ]
        then
            Pauze 'DRY RUN: Would run cp -iv '$wallpaper_source_pathname ${wallpaper_system_dirname}'/'
            return 0
        fi

        sudo cp -iv $wallpaper_source_pathname ${wallpaper_system_dirname}/ || return 7
        return 0

    fi

    return 1
}
# find ${wallpaper_system_dir}/ -name "$wallpaper_file" &

Report_Check_Setup_wallpaper() {
    local RCi=$1

    [[ $live_run == 'Y' ]] || return 0

    case $RCi in
        0)
            [[ $wallpaper_was_setup == 'N' ]] && echo 'Wallpaper successfully setup'
            Pauze 'Wallpaper is in place:'$wallpaper_system_path
            ;;
        1)
            Pauze 'WARNING, wallpaper setup will be done later...'
            ;;
        6)
            Pauze 'Invalid wallpaper source pathname '$wallpaper_source_pathname
            ;;
        5)
            Pauze 'Invalid wallpaper System Location: '$wallpaper_system_dirname
            ;;
        7)
            Pauze 'Cannot copy wallpaper to '$wallpaper_system_dirname
            ;;
        *)
            Pauze 'Invalid code:'${RCi}' Wallpaper report'
            ;;
    esac
    set +u
    return 0
}

Cleanup_nouser_nogroup() {
    Mark_nouser_nogroup_fix_run=$1

    [[ -e $Mark_nouser_nogroup_fix_run ]] && return 0

    sudo find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -uid 1000\
        -nouser -exec chown -c root {} \; & PIDnu=$!
    sudo find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -gid 1000\
        -nogroup -exec chgrp -c root {} \; & PIDng=$!
    (while [ ! -e $Mark_nouser_nogroup_fix_run ];do sleep 30;ps -ef |awk '{print $2}' |egrep "$PIDnu|$PIDng" >/dev/null||touch $Mark_nouser_nogroup_fix_run;done;chmod -c 600 $Mark_nouser_nogroup_fix_run || logger -t 'Prepare2Image' 'Problem concluding Nouser Nogroup fix') &

    return 0
}

while getopts $Optvalid OPT
do
    case $OPT in
        A)
            ADD_ALL='N'
            ;;
        P)
            PUR_ALL='N'
            ;;
        D)
            live_run='Y'
            Pauze 'LIVE RUN Selected. Control-C now to exit.'
            ;;
        B)
            Not_Batch_Run='Y'
            echo 'Interactive Run'
            ;;
        n)
            Set_Confirm_distro_name $OPTARG;RCx1=$?
            [[ $RCx1 -gt 11 ]] && exit $RCx1
            ;;
        R)
            aptcache_needs_update='N'
            ;;
        u)
            refresh_updatedb='Y'
            ;;
        V)
            refresh_svn='Y'
            ;;
        G)
            refresh_git='N'
            ;;
        h)
            echo $This_script\
            ': Valid options are [ -A -P -B -d{distro} -R -u -V -G -b{SrcBase} -h]'
            echo "A SET ADD_ALL='N'"
            echo "P SET PUR_ALL='N'"
            echo "B SET Not_Batch_Run='Y'"
            echo "n SET :Distro Name:"
            echo "R SET aptcache_needs_update='N'"
            echo "u SET refresh_updatedb='Y'"
            echo "V SET refresh_svn='Y'"
            echo "G SET refresh_git='N'"

            echo '(Match up with '$Optvalid')'
            exit 0
            ;;
        *)
            echo 'Unknown option: '${OPT}'. Exiting.'
            exit 8
            ;;
    esac
done
declare -x aptcache_needs_update
declare -x refresh_svn
declare -x refresh_git
declare -r ADD_ALL
declare -r PUR_ALL
declare -rx Not_Batch_Run

declare -r HOLDIFS=$IFS
This_script_dir=$(dirname $0)

Mainline

[[ -z $PIDnu ]] || echo 'Check on process '$PIDnu
[[ -z $PIDng ]] || echo 'Check on process '$PIDng

# Make the version-controlled tree - SOURCEBASE --
#  -- let child processes inherit (-x)

#PKGS='lm-sensors hddtemp ethtool gimp firefox dialog xscreensaver-gl libreoffice aptitude vim flashplugin-installer htop inxi vrms mintdrivers gparted terminator hardinfo'

