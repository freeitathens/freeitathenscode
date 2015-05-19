#!/usr/bin/perl -w
#use strict 'vars';
#
my $pkg_list_file=$ARGV[0] || '/dev/null';
open my $plist_handle (<,) || exit 16;
foreach my $plist_item {
}

#
#exit 0

Process_package() {
    IFS=','
    declare -ra pkg_info_a=($1)
    IFS=$HOLDIFS

    declare -r pkg_info_L=${#pkg_info_a[*]}
    pkg_name=${pkg_info_a[0]}
    pkg_by_addr_len=${pkg_info_a[1]}
    [[ pkg_by_addr_len -eq 0 ]] && pkg_by_addr_len=$address_len
    if [ $pkg_by_addr_len != $address_len ]
    then
        echo 'Skipping package '$pkg_name' on '$address_len' box.'
        return 0
    fi

    RCxE=0
    [[ $pkg_info_L -gt 3 ]] && (Check_extra $pkg_name ${pkg_info_a[3]} || RCxE=$?)
    [[ $RCxE -gt 10 ]] && return $RCxE

    RCxDS=0
    Pkg_by_distro_session ${pkg_info_a[2]} || RCxDS=$?

    return $RCxDS
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
        WHY)
            echo ${extra_a[1]}
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
