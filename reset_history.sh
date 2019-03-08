#!/bin/bash

function resetHistory() {
    local -a tags=( $(git tag --list) )

    echo
    echo $dir

    for tag in "${tags[@]}"; do
        [ "$tag" = 'v0.0' ] && continue
        git tag --delete "$tag"
        git push origin ":refs/$tag"
    done

    local repo=$(git config --get remote.origin.url)
    for branch in $(git ls-remote --heads "$repo" | awk '{print substr($2,12)}'); do
        [ "$branch" = 'dev' ] && continue
        git checkout "$branch"
        git reset --soft $(git rev-list --max-parents=0 HEAD)
        git add -A
        git commit -m 'reset history'
        git push --force
    done

    git checkout master
    git tag v3.4
    git push origin --tags
    git branch --delete dev
    git push origin --delete dev
    git checkout -b dev
    git push origin --set-upstream dev

    git lg
    read
}

declare -a dirs2=( base_container
                   bin
                   build_container
                   cesi
                   container_build_framework
                   files-kafka
                   files-librd
                   gradle
                   hubot
                   jenkins
                   kafka
                   kafka-i386
                   kafka-manager
                   kafka-ood
                   kafka-rest
                   kafka-zookeeper
                   movefiles
                   mysql
                   nagios
                   nginx-base
                   nginx-proxy
                   nginx_alt
                   nodervisor
                   openjdk
                   openjre
                   perl
                   perl-carton
                   php5
                   php7
                   phpmyadmin
                   postgresql
                   production-s1
                   production-s3
                   production-s4
                   supervisord
                   supervisord-monitor
                   webdav
                   zenphoto
               )

declare -a dirs=( support )

for d in "${dirs[@]}";do
    [ -d "$dir" ] || return 1
    pushd "$dir" &> /dev/null
    resetHistory 2>&1 | tee "../${dir}.txt"
    popd &> /dev/null
done
