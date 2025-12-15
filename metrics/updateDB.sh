#!/bin/bash

##############################################
# Environment variables supported
##############################################
# ACCUREV_STREAM
# BASH_SOURCE
# BUILD_NUMBER             00001
# CCACHE_CONFIG            1
# CFG_COMPONENT_BUILD      kittyhawk-all
# CFG_FLAVOR               DEBUG
# TRANSACTION_ID           head
# WORKSPACE                .
# USERNAME or USER         svc_ctdciauto
# !USER        



##############################################
## only ever define READ-ONLY vars in global scope

declare -r progname="$( basename "${BASH_SOURCE[0]}" )"

declare -r tools="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 
declare -r SQL_UPDATE_BUILDMETRICS_v1="${tools}/sql/buildmetrics.updateDB_v1.sql"
declare -r SQL_UPDATE_BUILDMETRICS_v2="${tools}/sql/buildmetrics.updateDB_v2.sql"
declare -r BLD_DEBUG='GNOSIS_DEBUG'
declare -r BLD_RETAIL='GNOSIS_RETAIL'
declare -r DBMS_NAME='ctd_datalake'
declare -r DBMS_USER='c4dev'
declare -r GIT_BRANCH='integration/harrier'
declare -r KITTYHAWK='kittyhawk-all'
declare -r LAST_GOOD_BUILD='LGB'
declare -r UNITY_PRODUCT='KH'

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
    $progname [<options>]  -b|--build_dir <build_dir>  -s|--stream|-r|--repo  <stream_or_repo>

    Common options:
        -h --help              Display a basic set of usage instructions
        -b --build_dir         Specify workspace directory containing build sources. Defaults to '${default_dir}'. 
           --cache_cfg         Set cache config flag to build_all
           --components        Component list to pass to build_all. Defaults to '${KITTYHAWK}'.
           --dbhost            Name of host for Postgres RDBMS. Defaults to '${DBMS_HOST}'
           --dbname            Name of database. Defaults to '${DBMS_NAME}'
           --dbuser            Name of use with write access to database. Defaults to '${DBMS_USER}'.
        -f --flavor            Build flavor [ DEBUG | RETAIL ] Defaults to 'DEBUG'.
        -g --gitbranch         GIT branch. Used to specifiy which sources to use. Defaults to '${GIT_BRANCH}'.
        -i --build_id          Build identifier. Defaults to '\$BUILD_NUMBER' environment variable (if set) or '00001'
        -m --meta_data         Name of metaData CSV file for saving data about build environment.
        -p --password          Password for SCM authentication. Defaults to '\$USER' environment variable.
           --prod_type         Product type. Defaults to '${UNITY_PRODUCT}'.
        -r --repo              GIT repository to populate build workspace.
        -s --stream            AccuRev stream to populate build workspace.
        -t --transaction       AccuRev transaction. Used to specify which sources to use. Defaults to '${LAST_GOOD_BUILD}'.
        -u --user              User for SCM authentiaction. Defaults to '\$!USER' environment variable.

Project: https://eos2git.cec.lab.emc.com/DevEnablement/CTD-Datalake_buildmetrics

EOF
    exit "$exit_status"
}

#----------------------------------------------------------------------------------------------
function main()
{
    # initalize values with defaults from environment variables (usefule for developers)
    local buildid=${BUILD_NUMBER:-'00001'}
    local build_dir=${WORKSPACE:-$(pwd)}
    local cache_cfg="$(check "$CCACHE_CONFIG")"
    local cleanup=${CFG_CLEANUP:-"cleanup_from_prior_builds.sh"}
    local components=${CFG_COMPONENT_BUILD:-"$KITTYHAWK"}
    local flavor=${CFG_FLAVOR:-'DEBUG'}
    local prod_type="$UNITY_PRODUCT"
    local stream_or_repo=${ACCUREV_STREAM}
    local dbname="$DBMS_NAME"
    local dbuser="$DBMS_USER"
    local dbhost=${DBMS_HOST:-'127.0.0.1'}
    local branch_or_transaction
    local metaDataFile 
    local user="$( getDefaultUser )"
    local password=${!user:-"${ACCUREV_PWD}"}
    local -r build_type='FULL_BUILD'
    
    # Parse command-line options into above variable
    local -r longopts='help,Help,HELP,build_dir:,cache_cfg,cleanup:,components:,dbname:,dbhost:,dbuser:,flavor:,gitbranch:,build_id:,meta_data:,password:,prod_type:,repo:,stream:,transaction:,user:'
    local -r shortopts='Hhb:c:f:g:i:m:p:r:s:t:u:'
    local -r options=$(getopt --longoptions "${longopts}" --options "${shortopts}" --name "$progname" -- "$@") || usage $?
    eval set -- "$options"
    while true; do 
        case "$1" in
            -h|--h|--help|-H|--H|--Help|--HELP)                  usage 0;;
            -b|--b|--build_dir)    build_dir="${2}";             shift 2;;
                   --cache_cfg)    cache_cfg="${2}";             shift 2;;
            -c|--c|--cleanup)      cleanup="${2}";               shift 2;;
                   --components)   components="${2}";            shift 2;;
                   --dbname)       dbname="${2}";                shift 2;;
                   --dbhost)       dbhost="${2}";                shift 2;;
                   --dbuser)       dbuser="${2}";                shift 2;;
            -f|--f|--flavor)       flavor="${2}";                shift 2;;
            -g|--g|--gitbranch)    branch_or_transaction="${2}"; shift 2;;
            -i|--i|--build_id)     buildid="${2}";               shift 2;;
            -m|--m|--meta_data)    metaDataFile="${2}";          shift 2;;
            -p|--p|--password)     password="${2}";              shift 2;;
                   --prod_type)    prod_type="${2}";             shift 2;;
            -r|--r|--repo)         stream_or_repo="${2}";        shift 2;;
            -s|--s|--stream)       stream_or_repo="${2}";        shift 2;;
            -t|--t|--transaction)  branch_or_transaction="${2}"; shift 2;;
            -u|--u|--user)         user="${2}";                  shift 2;;
            --) shift; break ;;
            *) echo "$1"; echo "Internal argument parsing error"; usage;;
        esac
    done

    [[ $build_dir ]] || build_dir="$( pwd )"
    [[ ${build_dir:0:1} != '/' ]] && build_dir="$(pwd)/${build_dir}"
    [[ -d $build_dir ]]  &&  build_dir="$( cd "$build_dir" && pwd )"
    [[ $cache_cfg == 0 ]] || cache_cfg=1
    [[ $flavor == "$BLD_DEBUG" ]]  &&  flavor='DEBUG'
    [[ $flavor == "$BLD_RETAIL" ]]  &&  flavor='RETAIL'
    [[ "$metaDataFile" ]] || metaDataFile="${build_dir}/output/${CSV_META}"


    # validate our args
    [[ "$user" && "$password" ]] || die "Credentials not set for authentication with USERNAME: $user"
    [[ $dbname ]] || die "Name of DBMS database missing"
    [[ $dbhost ]] || die "Name of DBMS host missing"
    [[ $dbuser ]] || die "Name of DBMS user missing"
    [[ $prod_type ]] || die "Product type of metaDataFile missing"
    [[ $stream_or_repo ]] || die "Stream/Repo information missing"
    [[ $flavor != DEBUG  &&  $flavor != RETAIL ]]  &&  die "Invalid build flavor specified: $flavor"
    [[ "$build_dir" == "$tools" ]] && die "Cannot builld in same location as $progname"
    [[ "$components" == "$KITTYHAWK" ]] && components='all'


    # parse 'stream_or_repo' definition to determine (GIT/AccuRev) functions to use 
    local FN_init_workspace
    local FN_getSCM_id
    local FN_populate_workspace
    local content_id
    if [[ "$stream_or_repo" == *'.git' ]]; then
        [[ $branch_or_transaction ]] || branch_or_transaction="$GIT_BRANCH"
        FN_init_workspace='initGitWorkspace'
        FN_getSCM_id='getGitCommit'
        FN_populate_workspace='populateGitWorkspace'
        content_id="${stream_or_repo}:refs/remotes/origin/${GIT_BRANCH}"
    else
        [[ $branch_or_transaction ]] || branch_or_transaction=${TRANSACTION_ID:-"$LAST_GOOD_BUILD"}
        FN_init_workspace='initAccuRevWorkspace'
        FN_getSCM_id='getAccurevTxn'
        FN_populate_workspace='populateAccuRevWorkspace'
        content_id="$stream_or_repo"
    fi

    
    echo ''
    echo "== building on      = $( getFullyQualifiedDomainName ) : [ $( getIPaddress ) ]"
    echo "== DBMS host        = $dbhost"
    echo "== DBMS user        = $dbuser"
    echo "== DBMS database    = $dbname"
    echo "== cleanup          = $cleanup"
    echo "== product          = $prod_type"
    echo "== ccache flag      = $cache_cfg"
    echo "== build components = $components"
    echo "== build flavor     = $flavor"
    echo "== build workspace  = $build_dir"
    echo "== build id         = $buildid"
    echo "== metaDataFile     = $metaDataFile" 
    echo "== SCM location     = $stream_or_repo"
    echo "== SCM source ref   = $branch_or_transaction"
    echo ''
    

    #execute 'cleanup' script if it exists
    [[ -e "$cleanup" ]] && ( eval "PATH=.:${tools}:${PATH}  $cleanup"  > /dev/stdout 2>&1 || true )


    #delete old metadafile if it exists
    [[ -e "$metaDataFile" ]] && sudo rm "$metaDataFile"


    #initialize workspace
    removeOldWorkspace "$build_dir"
    "$FN_init_workspace" "$stream_or_repo" "$user" "$password"



    #find the SCM identifier for the sources we plan to use
    local -r build_txn=$(eval "${FN_getSCM_id}" "$stream_or_repo"             \
                                                "$branch_or_transaction")


    echo ''
    echo "== SCM source ID    = $build_txn"
    echo ''


    #update workspace
    "$FN_populate_workspace" "$stream_or_repo"                                \
                             "$flavor"                                        \
                             "$build_txn"


    # Run the build
    local -i build_all_version=2  # need a better way to determine this
    runBuild "$build_dir"                                                     \
             "$components"                                                    \
             "$cache_cfg"



    #generate meta data for build
    generateBuildMetaData "$( getSysDateTime )"                               \
	                  "$prod_type"                                        \
	                  "$( getIPaddress )"                                 \
	                  "$flavor"                                           \
	                  "$content_id"                                       \
	                  "$build_txn"                                        \
	                  "$cache_cfg"                                        \
	                  "$( getNumCPUs )"                                   \
	                  "$( getMemorySize )"                                \
                          "$metaDataFile"                                     \
                          "$build_all_version"                                \
                          "$build_type"


    # load CSV data into build_metrics schema in datalake
    local -r update_sql="SQL_UPDATE_BUILDMETRICS_v${build_all_version}"
    updateRDBMS_BUILDMETRICS "$( getHost )"                                   \
                             "$build_dir"                                     \
                             "$metaDataFile"                                  \
                             "$buildid"                                       \
                             "$dbhost"                                        \
                             "$dbname"                                        \
                             "$dbuser"                                        \
                             "${!update_sql}"

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
