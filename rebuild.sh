#!/bin/bash

. /home/bobb/.inf/docker.inf

set -o errexit
set -o nounset  
#set -o xtrace
#set -o verbose

declare -r TOOLS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"  
declare -r BASE_DIR=/home/bobb/prod
declare -r progname="$( basename "${BASH_SOURCE[0]}" )" 

export  CONTAINER_TAG="$( date +%Y%m%d )"
export  CBF_VERSION=v3.0

#--------------------------------------------
function fullBuild()
{
    docker-compose build || exit 1
    docker-compose down
    docker-compose rm -f
    rmOldContainers
    rmLogs 'all'
    docker-compose up -d
}

#--------------------------------------------
function main()
{
    # Parse command-line options
    declare -r longopts='help,Help,HELP,all:container:'
    declare -r shortopts='Hh:a:c'
    declare -r options=$(getopt --longoptions "${longopts}" --options "${shortopts}" --name "$progname" -- "$@")
    if [[ "$#" -gt 0 ]]; then
        while true; do 
            case "$1" in
                -h|--h|--help|-H|--H|--Help|--HELP)              usage 0;;
                -a|--a|--all)                          fullBuild; break;;
                -c|--c|--container)          partialBuild "${2}"; break;;
                *)                           partialBuild "${1}"; break;;
            esac
        done
    else
        fullBuild
    fi
}

#--------------------------------------------
function partialBuild()
{
    local container_name=$1

    if [[ $container_name = 'all' ]]; then
        fullBuild
        
    else
        docker-compose build "${container_name}" || exit 1
        docker-compose stop "${container_name}"
        docker-compose rm -f
        rmLogs "${container_name}"
        docker-compose up -d
        rmOldContainers
    fi
}

#--------------------------------------------
function rmLogs()
{
    local dir=$1

    if [[ $dir == all ]]; then
        while read dir; do
            rmLogs "$dir"
        done < <(find "$BASE_DIR" -maxdepth 1 -type d)
        
    elif [[ $dir != "$BASE_DIR" && $dir != "$BASE_DIR/vols" ]]; then
        while read log; do
            echo "deleting logs from $log"
            rm -rf "$log"/*
        done < <([[ -d $dir ]] && find $dir -maxdepth 3 -name 'log' -type d | grep 'vols/log')
    fi
}

#--------------------------------------------
function rmOldContainers()
{
    [[ $(docker ps -a --filter "name=_" --format "{{.Names}}") ]] && \
        docker rm -f $(docker ps -a --filter "name=_" --format "{{.Names}}")
    [[ $(docker ps -a --filter "status=exited" --filter "status=dead" --format "{{.Names}}") ]] && \
        docker rm $(docker ps -a --filter "status=exited" --filter "status=dead" --format "{{.Names}}")
    [[ $(docker images -f "dangling=true" -q) ]] && \
    docker rmi $(docker images -f "dangling=true" -q)
}

#----------------------------------------------------------------------------------------------
function usage()
{
    local -i exit_status=${1:-1}

    cat >&2 << EOF
Usage:
    $progname [<options>]  -a|--all  -c|--container  <container_name>

    Common options:
        -h --help              Display a basic set of usage instructions
        -a --all               rebuild all containers
        -c --container         rebuild specific container

EOF
    exit "$exit_status"
}

#--------------------------------------------


# ensure this script is run as root
if [[ $EUID != 0 ]]; then
    sudo -E $0 "$*"
    exit
fi
    
cd "$BASE_DIR"

main $@