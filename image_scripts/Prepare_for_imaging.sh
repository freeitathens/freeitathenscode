#!/bin/bash +x
[[ 0 -ne $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]] &&\
    read -p'NOTE: Permission Problems? Rerun with sudo (i.e., as root).<ENTER>' -t5

This_script=$(basename $0)
This_script_dir=$(dirname $0)

distro_name=''
Set_Confirm_distro_name() {
    distro_name=$1
    [[ -z $distro_name ]] && return 40

    echo -e "\n\e[1;32;40mEvaluating your input: ${distro_name}\n"
    read -p'<ENTER>' -t3

    Set_sys_rpts_distro_name;RCxS=$?
    if [ $RCxS -gt 0 ]
    then
        echo 'Cant confirm your distro name '\
            $distro_name' against the system name(s)'
        read -p'<ENTER>' -t3
        return 2
    fi

    if [ "${distro_name}." == "${sys_rpts_distro_name}." ]
    then
        echo 'System distro value ('${sys_rpts_distro_name}\
    ') agrees with your input ('${distro_name}').'
        read -p'<ENTER>' -t3
        return 0
    fi

    echo 'System distro value ('\
        ${sys_rpts_distro_name}\
          '): mismatch (however slight) with input: ('\
        ${distro_name}').'
    read -p'<ENTER>' -t3

    return 3
}

sys_rpts_distro_name=0
Set_sys_rpts_distro_name() {

    sys_rpts_distro_name=$(lsb_release -a 2>/dev/null\
            |grep '^Distributor ID:'|cut -f2 -d:\
            |sed -e 's/^[ \t]*//')

    if [ -n ${sys_rpts_distro_name} ]
    then
        echo 'System reports distro as '${sys_rpts_distro_name}'.'
        read -p'<ENTER>' -t3
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

UserSet_sourcebase() {

    declare -a sourcb_read_arr
    echo 'Normally FreeIT Code is in '$sourcebase
    read -p 'Your Code Location? ' -a sourcb_read_arr
    sourcb_read_LEN=${#sourcb_read_arr[@]}
    [[ sourcb_read_LEN -eq 0 ]] && return 0

    hold_sourcebase=${sourcb_read_arr[0]}
    [[ "$hold_sourcebase" =~ 'EXIT' ]] && exit 2

    [[ -d $hold_sourcebase ]] || exit 13
    sourcebase=$hold_sourcebase

    return 0
}

declare -x Runner_shell_hold=$-
declare -x aptcache_needs_update='Y'
refresh_updatedb='N'
refresh_svn='N'
declare -x refresh_git='Y'

# Establish base of version-controlled code tree.
sourcebase="/home/oem/freeitathenscode"

Optvalid='jVRuGhd:b:'
while getopts $Optvalid OPT
do
    case $OPT in
        j)
            echo \$- 'captured as '$Runner_shell_hold
            Runner_shell_hold=${Runner_shell_hold}'i'
            echo '...now set to '$Runner_shell_hold
        read -p'<ENTER>' -t3
            ;;
        d)
            Set_Confirm_distro_name $OPTARG;RCx1=$?
            [[ $RCx1 -gt 11 ]] && exit $RCx1
            ;;
        R)
            export aptcache_needs_update='N'
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
        b)
            UserSet_sourcebase
            ;;
        h)
            echo $This_script\
        ': Valid options are [ -j -V -R -u -G -d{Distro} -b{SrcBase} -h]'
            echo '(Matches up with '$Optvalid'?'
        read -p'<ENTER>' -t3
            exit 0
            ;;
        *)
            echo 'Unknown option: '${OPT}'. Exiting.'
        read -p'<ENTER>' -t3
            exit 8
            ;;
    esac
done

[[ -d $sourcebase ]] || exit 25

# Make the version-controlled tree - sourcebase --
#  -- an unchangable value (-r)
#  -- let child processes inherit (-x)
declare -rx sourcebase

# Establish location of Common Functions within sourcebase
codebase=${sourcebase}'/image_scripts'
[[ -d $codebase ]] || exit 14
declare -rx codebase
source ${codebase}/Common_functions || exit 135
source ${codebase}/Prepare_functions || exit 136

declare -r HOLDIFS=$IFS
declare -rx Messages_O=$(mktemp -t "Prep_log.XXXXX")
declare -rx Errors_O=$(mktemp -t "Prep_err.XXXXX")

FreeIT_image='FreeIT.png'

declare -rx Runner_shell_as=${Runner_shell_hold}

[[ "${refresh_updatedb}." == 'Y.' ]] && updatedb &

Correct_subversion_ssh() {
    for subv_home in ${HOME}/.subversion /etc/subversion
    do
        [[ -d ${subv_home} ]] || break

        subv_conf="${subv_home}/config"
        if [ -f ${subv_conf} ]
        then
            Answer='N'
            Pause_n_Answer 'Y|N' "Fix $subv_conf for Frita's ssh connection (Y|N)? "
            case $Answer in
                Y)
                    sudo perl -pi'.bak' -e 's/#\s*ssh\b(.+?ssh)\s+-q(.+)$/ssh${1} -v${2}/' ${subv_conf}
                    [[ $? -eq 0 ]] && break
                    ;;
                *)
                    prettyprint 'n,t,34,47,M,0' 'No changes made...'
                    ;;
            esac
        fi
    done

    return 0
}

Set_background() {
    local Image_file=$1
    [[ -z "$Image_file" ]] && return 6
    local Image_dir=$2
    [[ -z "$Image_dir" ]] && return 9
    [[ -d "$Image_dir" ]] || return 5
    shift 2

    Have_BG=$(ls -l ${Image_dir}/$Image_file)
    if [ $? -gt 0 ]
    then
        Pauze 'WARNING,OK, Background needs setup. First, searching all subdirs...'
        find ${Image_dir}/ -name "$Image_file" &
        Answer='Y'
        Pause_n_Answer 'Y|N' 'INFO,Shall I try to retrieve '$Image_file' (Default '$Answer')?'
        if [ "${Answer}." == 'Y.' ]
        then
            sudo cp -iv ${codebase}/$Image_file ${Image_dir}/ || return 15
        else
            Pauze 'WARNING,OK, Handle it later...'
        fi
    fi
}

address_len=0
Get_Address_Len

distro_name_Set() {

    Pauze 'No distro supplied in parms. (e.g., -d FRITAROX)...'
    Set_sys_rpts_distro_name;RCxS=$?
    [[ $RCxS -eq 0 ]] || return 30

    Answer='N'
    Pause_n_Answer 'Y|N' '...system value '${distro_name}' is used, OK? '
    [[ "${Answer}." == 'Y.' ]] || return 12
    distro_name=$sys_rpts_distro_name

    return 0
}
RCxD=0
[[ -z $distro_name ]] && distro_name_Set || RCxD=$?
No_distro_name_bye() {
    prettyprint '1,31,40,M,n' 'Cannot Set Distro name'
    Pauze 'Exiting....'
    exit $RCxD
}
[[ $RCxD -eq 0 ]] || No_distro_name_bye

Confirm_DISTRO_CPU() {

    distro_valid_flag='?'
    prettyprint '1,32,40,M,0' $distro_name' is'
    case $distro_name in
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
    Pauze "INFO,Confirmed $distro_name on ${address_len}-bit box."

    return 0

}
RCxDC=0
Confirm_DISTRO_CPU;RCxDC=$?
User_no_distro_bye() {
    prettyprint '5,31,47,M,n,0' 'Exiting'
    Pauze "See you back soon!"
    exit $RCxDC
}
[[ $RCxDC -eq 0 ]] || User_no_distro_bye

echo 'Check (absence of) local UUID reference for swap in fstab.'
RCxU=1
grep -P 'UUID.+swap' /etc/fstab && RCxU=$?
if [ $RCxU -eq 0 ]
then
    Pauze 'fstab cAnNoT gO oN iMaGe wItH lOcAl UUID reference. Entering editor...'
    sudo vi /etc/fstab
fi
Pauze '(DONE) Check (absence of) local UUID reference for swap in fstab.'

echo 'Checking swap'
Run_Cap_Out swapoff --all --verbose
Run_Cap_Out swapon --all --verbose
Pauze '(DONE) Checking swap'

#Pauze 'Confirm no medibuntu in apt sources'
#egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list

echo "Checking if apt update is needed( COND: $aptcache_needs_update )"
Run_apt_update
Pauze "(DONE) apt update ( COND: $aptcache_needs_update )"

echo "Check that server address is correct and is contactable ( COND: $refresh_svn )"
Contact_server() {
    Sub_lcl_stat() {
    echo 'Check on subversion local repo status'
    if [ -d ${sourcebase}/.svn ]
                then
        cd ${sourcebase}/
        svn update
    else
        apt-get install subversion
        cd
        Correct_subversion_ssh
        svn co svn+ssh://frita@192.168.1.9/var/svn/Frita/freeitathenscode/
    fi
    Pauze '(DONE) Check on subversion local repo status'
}
    [[ $(ssh -p8222 frita@192.168.1.9 'echo $HOSTNAME') =~ 'nuvo-servo' ]]\
        && Pauze 'Checked Server is valid: 192.168.1.9' && Sub_lcl_stat && return $?

    return 1
}
[[ "${refresh_svn}." == 'Y.' ]] && Contact_server
Pauze "(DONE) Check that server address is correct and is contactable ( COND: $refresh_svn )"

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
    read -p' <Add to APT Repos?>' -a ANS || return 4
    [[ ${#ANS[*]} -eq 0 ]] && return 0
    if [ ${ANS[0]} == 'Y' ]
    then
        add-apt-repository $apt_repo_name || return $?
	return 0
    fi

    return $?
}

RCxPK=-1
echo 'Install necessary packages'
Install_packages_from_file_list() {
    local pkg_file=$1
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
                    Establish_ppa_repo_sourcefile $pkg_name ${extra_a[1]}
                    RCxPPA=$?
                    if [ $RCxPPA -gt 10 ]
                    then
                    return $RCxPPA
                    fi
                    if [ $RCxPPA -gt 0 ]
                    then
                    return 0
                    fi 
                    ;;
		INSTALL)
		    echo 'Check that '${extra_a[1]}' replaces '$pkg_name
		    ;;
		REMOVE)
		    echo 'Check that '$pkg_name' replaces '${extra_a[1]}
		    ;;
                *)
                    echo 'Unknown Extra Code:'$pkg_extra' for '$pkg_name
                    return 6
                    ;;
                esac
                return 115
       }
       RCxE=0
       [[ $pkg_info_L -gt 3 ]] && Check_extra $pkg_name ${pkg_info_a[3]} || RCxE=$?
       [[ $RCxE -gt 10 ]] && return $RCxE

       Pkg_by_distro_session() {
           distro_session=$1

           Pkg_purge() {
               echo -n $pkg_name' '
               read -p'<Purge?>' -a ANS || return 0
    	       [[ ${#ANS[*]} -eq 0 ]] && return 0
               if [ ${ANS[0]} == 'Y' ]
               then
                   Apt_purge $pkg_name || return $?
               fi
           }
           Pkg_add() {
               echo -n $pkg_name' '
	       read -p'<Install/Upgrad3(Y|n)?>' -a ANS || return 0
	       [[ ${#ANS[*]} -eq 0 ]] && return 0
               if [ ${ANS[0]} == 'Y' ]
               then
                   Apt_install $pkg_name || return $?
               fi
           }
           case $distro_session in
              NONE)
                  Pkg_purge ||return 20
                  ;;
              ALL)
                  Pkg_add || return 21
                  ;;
              $distro_generia)
                  Pkg_add || return 21
                  ;;
           esac
           return 1
        }
        Pkg_by_distro_session ${pkg_info_a[2]};RCxDS=$?
    }
    for pkg_info_csv in $(grep -v '^#' $pkg_file)
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
for pkg_file in $(find $This_script_dir -maxdepth 1 -type f -name 'Packages*')
do
    RCxPK=0
    Install_packages_from_file_list $pkg_file || RCxPK=$?
done
[[ $RCxPK -ne 0 ]] && echo 'Problems Installing Packages:'$RCxPK
Pauze '(DONE) Install necessary packages'

set -u
Pauze 'Try to set Frita Backgrounds'
backmess='Background Set?'
case $distro_generia in
    lubuntu|ubuntu)
        Backgrounds_location='/usr/share/lubuntu/wallpapers'
        ;;
    *)
        Backgrounds_location='/usr/share/backgrounds'
        ;;
esac
Pauze 'DONE: set Frita Backgrounds'

echo 'Checking background file location: $Image_dir / $Image_file'
Set_background $FreeIT_image $Backgrounds_location
bg_RC=$?
case $bg_RC in
    0) backmess='Background setting ok'
    ;;
    5) backmess="Invalid backgrounds directory ${Backgrounds_location}. Set background manually"
    ;;
    6) backmess='Invalid background filename '$FreeIT_image
    ;;
    *) backmess="Serious problems with setting background. RC=${bg_RC}"
    ;;
esac
echo "Response from setting Frita Backgrounds was $backmess"
Pauze "(DONE) Checking background file location: $Image_dir / $Image_file"

case $distro_generia in
    mint)
        Pauze 'WARNING,Ensure backports in /etc/apt/sources.list (or sources.d/)' 
        ;;
    *)
        Pauze 'Assuming Backports are automatically included'
        ;;
esac

echo 'mint and mate specials'
if [ $address_len -eq 64 ]
then
    grep -o -P '^OnlyShowIn=.*MATE' /usr/share/applications/screensavers/*.desktop 
    Pauze 'Mate Desktop able to access xscreensavers for ant spotlight?'
fi
Pauze '(DONE) mint and mate specials'

case $distro_generia in
    lubuntu|ubuntu|mint)
        echo 'Run BPR Code'
        [[ -f ${codebase}/BPR_custom_prep.sh ]] &&\
            ${codebase}/BPR_custom_prep.sh
        Pauze "Run BPR: Last return code: $?"
        ;;
    *)
        Pauze "Don't need to run BPR additions for "$distro_generia' ('$distro_name')'
        ;;
esac

Pauze 'apt-get update ( COND: '$aptcache_needs_update ')'
if [ $aptcache_needs_update == 'Y' ]
then
    apt-get update
    export aptcache_needs_update='N'
fi
Pauze 'apt dist-upgrade'
apt-get dist-upgrade

Pauze 'Lauching Virtual Greybeard'
vrms
Pauze '/\Please Purge Non-Free Stuff IF NEEDED/\'

Pauze "Ensuring that QC.sh and revert_prep... are properly linked in ${HOME}/bin" 
local_scripts_DIR="${HOME}/bin"
[[ -d $local_scripts_DIR ]] || mkdir $local_scripts_DIR
chown -c oem $local_scripts_DIR
[[ -e ${local_scripts_DIR}/QC.sh ]] || ln -s ${sourcebase}/QC_Process/QC.sh ${local_scripts_DIR}/QC.sh
[[ -e ${local_scripts_DIR}/revert_prep_for_shipping_to_eu ]]\
    || ln -s ${codebase}/revert_prep_for_shipping_to_eu ${local_scripts_DIR}/revert_prep_for_shipping_to_eu 

Pauze 'Confirming that the correct Run Quality Control icon is in place...'
(find ${sourcebase}/QC_Process -iname 'Quality*' -exec md5sum {} \; ;\
    find ${sourcebase}/QC_process_dev/Master_${address_len} -iname 'Quality*' -exec md5sum {} \; ;\
    find ${HOME}/Desktop -iname 'Quality*' -exec md5sum {} \;) |grep -v '\.svn' |sort

Mark_nouser_nogroup_fix_run="${HOME}/Ran_nouser_nogroup_fix"
if [ ! -e $Mark_nouser_nogroup_fix_run ]
then
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -uid 1000\
    -nouser -exec chown -c root {} \; & PIDnu=$!
    find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -gid 1000\
    -nogroup -exec chgrp -c root {} \; & PIDng=$!
    (while [ ! -e $Mark_nouser_nogroup_fix_run ];do sleep 30;ps -ef |awk '{print $2}' |egrep "$PIDnu|$PIDng" >/dev/null||touch $Mark_nouser_nogroup_fix_run;done;chmod -c 600 $Mark_nouser_nogroup_fix_run || logger -t 'Prepare2Image' 'Problem concluding Nouser Nogroup fix') &
fi

#PKGS='lm-sensors hddtemp ethtool gimp firefox dialog xscreensaver-gl libreoffice aptitude vim flashplugin-installer htop inxi vrms mintdrivers gparted terminator hardinfo'

