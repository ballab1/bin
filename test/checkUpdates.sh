#!/bin/bash

function myChecker()
{
    local -r dir=${1:?}


    pushd "${dir}" > /dev/null
    echo "$(git rev-parse HEAD) :: $(pwd)"
    for d in $(git submodule status --recursive | awk '{print $2}'); do
        pushd $d > /dev/null
        echo "$(git rev-parse HEAD) :  $(pwd)"
        popd > /dev/null
    done
    popd > /dev/null
}

declare -a dirsToCheck=(  '/home/bobb/GIT/elk-deploy'
                          '/home/bobb/GIT/kafka-deploy-s1'
                          '/home/bobb/GIT/kafka-deploy-s3'
                          '/home/bobb/GIT/kafka-deploy-s4'
                          '/home/bobb/GIT/nagios-deploy'
                          '/home/bobb/GIT/smee-deploy'
                          '/home/bobb/GIT/support'
                          '/home/bobb/GIT/utilities' )

for d in "${dirsToCheck[@]}"; do
    myChecker "$d"
done