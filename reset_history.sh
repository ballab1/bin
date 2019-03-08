#!/bin/bash

function resetHistory2() {
    local -a tags=( $(git tag --list) )
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
}

function resetHistory() {
    local dir=${1:-$repo}

    echo
    echo $dir
    [ -d "$dir" ] || return 1
    pushd "$dir" &> /dev/null
    resetHistory2 2>&1 | tee "../${dir}.txt"
    git lg
    read
    popd &> /dev/null
}

resetHistory base_container
resetHistory build_container
resetHistory cesi
resetHistory container_build_framework
resetHistory files-kafka
resetHistory files-librd
resetHistory gradle
resetHistory hubot
resetHistory jenkins
resetHistory kafka
resetHistory kafka-manager
resetHistory kafka-rest
resetHistory kafka-zookeeper
resetHistory libs
resetHistory movefiles
resetHistory mysql
resetHistory nagios
resetHistory nginx_alt
resetHistory nginx-base
resetHistory nginx-proxy
resetHistory nodervisor
resetHistory openjdk
resetHistory openjre
resetHistory perl
resetHistory perl-carton
resetHistory php5
resetHistory php7
resetHistory phpmyadmin
resetHistory postgresql
resetHistory supervisord
resetHistory supervisord-monitor
resetHistory webdav
resetHistory zenphoto
