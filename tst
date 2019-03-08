#!/bin/bash

set -o errexit
declare progname=$( basename $0 )

#-----------------------------------------------------------------------------------
function docker_revert()
{
    if [[ -e docker-compose.yml.old ]]; then
        docker-compose down && true
        mv docker-compose.yml docker-compose.yml.new
        mv docker-compose.yml.old docker-compose.yml
    fi
    docker_start
}

#-----------------------------------------------------------------------------------
function docker_start()
{
    docker-compose up -d
    docker ps
}

#-----------------------------------------------------------------------------------
function docker_stop()
{
    docker-compose down && true
    docker ps
}

#-----------------------------------------------------------------------------------
function docker_test()
{
    if [[ -e docker-compose.yml.new ]]; then
        docker-compose down && true
        mv docker-compose.yml docker-compose.yml.old
        mv docker-compose.yml.new docker-compose.yml
    fi
    docker_start
}

#-----------------------------------------------------------------------------------
function usage()
{
    declare exit_status=${1:-1}
    declare extended_help=${2:-0}

    cat >&2 << EOF
Usage:
    $progname [<options>]

    Common options:
        -h --help       Display a basic set of usage instructions
        -r --revert     revert to known last running config
        -s --start      start docker-compose
        -t --test       test latest changes
        -x --stop       Stop docker processes

Current status:
EOF
        cd ~/production
        docker ps
        ls docker-compose.*
}


#-----------------------------------------------------------------------------------
# Process command line arguments
main()
{
    while [ "$1" != "" ]
    do
        case $1 in
        -h|--help)   usage; exit 1;;
        -r|--revert) docker_revert ; exit 0;;
        -s|--status) dcker_status ; exit 0;;
        -t|--test)   docker_test ; exit 0;;
        -x|--stop)   docker_stop ; exit 0;;
        *)           echo 'need to specify something'; exit 1;;
        esac
        shift
    done
}

#-----------------------------------------------------------------------------------

main "$@"

