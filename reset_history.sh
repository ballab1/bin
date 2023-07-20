#!/bin/bash

function resetHistory() {
    echo
    echo $dir

    for tag in $(git tag --list); do
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

    git checkout main
    git tag v3.4
    git push origin --tags
    git branch --delete dev
    git push origin --delete dev
    git checkout -b dev
    git push origin --set-upstream dev

    git lg
    read
}

function resetHistoryOnDirs() {

local -a dirs=(    base_container
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
                   support
                   webdav
                   zenphoto
               )

    for d in "${dirs[@]}";do
        [ -d "$dir" ] || return 1
        pushd "$dir" &> /dev/null
        resetHistory 2>&1 | tee "../${dir}.txt"
        popd &> /dev/null
    done
}

declare -a skip=( base_container
                  cesi
                  build_container
                  container_build_framework
                  files-kafka
                  files-librd
                  jenkins
                  gradle
                  hubot
                  kafka
                  kafka-manager
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
                 )

for dir in $(git submodule status | awk '{print $2}'); do

    [ $(printf '%s\n' "${skip[@]}" | grep -cs "$dir") -gt 0 ] && continue
    pushd $dir &>/dev/null

    echo
    echo $dir
    git fetch --tags
    for tag in $(git tag --list); do
        [ "$tag" = 'v0.0' ] && continue
        git tag --delete "$tag"
        git push origin :refs/tags/$tag
    done

    declare repo=$(git config --get remote.origin.url)
    for branch in $(git ls-remote --heads "$repo" | awk '{print substr($2,12)}'); do
        git checkout $branch
        git reset --hard $(git rev-list --max-parents=0 HEAD)
        git clean -dfx
        git pull
    done

    git checkout main
    git tag v3.4
    git push origin --tags
    git checkout dev

    git lg
    read

    popd &>/dev/null
done