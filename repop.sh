#!/bin/sh

function checkout() {
    local repo=${1:?}
    local dir=${2:-$repo}
    local branch=${3:-}

    [ "${branch:-}" ] && branch="-b $branch"

    rm -rf "$dir"
    git clone --recursive ${branch:-} "https://github.com/ballab1/$repo" "$dir"
}

cd /c/home.config

checkout production-s1
checkout production-s3
checkout production-s4
checkout bin
checkout versions
checkout jenkins-pipelines
checkout jenkins-sharedlibs
checkout support v3.3-support dev
