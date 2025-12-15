#!/bin/bash

function my.capture()
{
    local -r capture="$tmpUserDir/$(date +"%Y%m%d%H%M%S.%N")"
    mkdir -p "$capture"
    cd "$capture"

    ssh bobb@ubuntu-s3 docker logs jenkins &> jenkins.log
    sudo cp -r /var/log/containers .
    sudo cp -r /var/log/pods .
    sudo cp /var/log/syslog .
    echo "$capture"
}

function my.diff()
{
    local -r start=${1:?}
    local -r after=${2:?}

    while read -r dir; do
        :
    done < <(cd "$start";find . -type f)
}

declare -r tmpUserDir="${TMPDIR:-/tmp}/$USER_$(date +"%Y%m%d%H%M%S")"
declare start=$(my.capture)

echo 'capturing data'
mkdir -p "$tmpUserDir"
chown bobb:bobb "$tmpUserDir"
chmod 755 "$tmpUserDir"
sudo tcpdump -i enp2s0 -w "$tmpUserDir/tmpdump.dat"

declare after=$(my.capture)
sudo chown bobb:bobb -R "$tmpUserDir"

my.diff "$start" "$after"
