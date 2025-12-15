#!/bin/bash


##############################################
# Environment variables supported
##############################################
# BASH_SOURCE
# WORKSPACE                .


##############################################
## only ever define READ-ONLY vars in global scope

declare -r progname="$( basename "${BASH_SOURCE[0]}" )"

declare -r tools="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 
declare -r SQL_UPDATE_BUILDMETRICS_v1="${tools}/sql/buildmetrics.updateDB_v1.sql"
declare -r SQL_UPDATE_BUILDMETRICS_v2="${tools}/sql/buildmetrics.updateDB_v2.sql"
declare -r DBMS_NAME='ctd_datalake'
declare -r DBMS_USER='c4dev'

##############################################
# load library functions
#
. "${tools}/bashFunctions"


#----------------------------------------------------------------------------------------------
function usage()
{
    local -i exit_status=${1:-1}
    local default_dir=${WORKSPACE:-'current directory'}
    default_dir="<${default_dir}>"

    cat >&2 << EOF
Usage:
    $progname [<options>]  -d <csv_dir>

    Common options:
        -h --help              Display a basic set of usage instructions
        -c --csv_dir           Directory containing previously generated csv files
           --dbhost            Name of host for Postgres RDBMS. Defaults to '${DBMS_HOST}'
           --dbname            Name of database. Defaults to '${DBMS_NAME}'
           --dbuser            Name of use with write access to database. Defaults to '${DBMS_USER}'.

Project: https://eos2git.cec.lab.emc.com/DevEnablement/CTD-Datalake_buildmetrics

EOF
    exit "$exit_status"
}

#----------------------------------------------------------------------------------------------
function main()
{
    # initalize values with defaults from environment variables (usefule for developers)
    local dbname="$DBMS_NAME"
    local dbuser="$DBMS_USER"
    local dbhost=${DBMS_HOST:-'127.0.0.1'}

    
    # Parse command-line options into above variable
    local -r longopts='help,Help,HELP,csv_dir:,dbname:,dbhost:,dbuser:'
    local -r shortopts='Hhc:'
    local -r options=$(getopt --longoptions "${longopts}" --options "${shortopts}" --name "$progname" -- "$@") || usage $?
    eval set -- "$options"
    while true; do 
        case "$1" in
            -h|--h|--help|-H|--H|--Help|--HELP)                  usage 0;;
            -c|--c|--csv_dir)      csv_dir="${2}";               shift 2;;
                   --dbname)       dbname="${2}";                shift 2;;
                   --dbhost)       dbhost="${2}";                shift 2;;
                   --dbuser)       dbuser="${2}";                shift 2;;
            --) shift; break ;;
            *) echo "$1"; echo "Internal argument parsing error"; usage;;
        esac
    done

    # validate our args
    [[ "$csv_dir" ]] || die "Location of csv files not specified"
    [[ $dbname ]] || die "Name of DBMS database missing"
    [[ $dbhost ]] || die "Name of DBMS host missing"
    [[ $dbuser ]] || die "Name of DBMS user missing"

    
    local -i buildid="$( basename "$csv_name" )"
    local -r slave="$( basename "$( dirname "${csv_dir}" )" )"


    echo ''
    echo "== csv directory    = $csv_dir"
    echo "== slave            = $slave"
    echo "== buildid          = $buildid"
    echo "== DBMS host        = $dbhost"
    echo "== DBMS user        = $dbuser"
    echo "== DBMS database    = $dbname"
    echo ''


    # load CSV data into build_metrics schema in datalake
    local -i build_all_version=2  # need a better way to determine this
    local -r update_sql="SQL_UPDATE_BUILDMETRICS_v${build_all_version}"
    updateRDBMS_BUILDMETRICS "$slave"                                          \
                             "$csv_dir"                                        \
                             "${csv_dir}/${CSV_META}"                          \
                             "$buildid"                                        \
                             "$dbhost"                                         \
                             "$dbname"                                         \
                             "$dbuser"                                         \
                             "${!update_sql}"                                  \
                             "nocopy"

    local -i status=$?
    return "$status"
}

#----------------------------------------------------------------------------------------------

trap catch_error ERR
trap catch_int INT
trap catch_pipe PIPE

# Run script
[[ "$@" ]] || usage
[[ $0 != "$BASH_SOURCE" ]] || { main "$@"; exit; } 