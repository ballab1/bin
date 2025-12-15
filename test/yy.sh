#!/usr/bin/bash

function create_registry_defs() {

    local SNAP_DATA="${1:-/etc/containerd/config.toml}"
    local version="${2:-}"
    local configPath="${SNAP_DATA}/args/certs.d"
    shift 2

    printf '\- %s\n' "$@"

    local host
    for host in "$@"; do
        echo "settings for $host"
        local reg="http://${host}"
        mkdir -p "${configPath}/$host"
        cat << REGISTRY > "${configPath}/${host}/hosts.toml"
server = "$reg"

[host."$reg"]
  capabilities = ["pull", "resolve"]
REGISTRY
        sudo chown -R root:microk8s "${configPath}/$host"
    done
}

function registry_refs() {

    local registry="$(sed -E -e 's|^(.+):.*$|\1|' <<< "${REGISTRY}")"
    declare -a args
    # nslookup 's2.ubuntu.home' | awk '{if((NR==5 && match($1,"^Name")>0)||(NR != 2 && match($1,"^Address")>0)){print $2 ":5000"}}'
    nslookup "${registry}" | awk '{if((NR==5 && match($1,"^Name")>0)||(NR != 2 && match($1,"^Address")>0)){print $2 ":5000"}}'
}


SCRIPT="$0"
START="$(date +%s)"
BASHLIB_DIR='/home/bobb/.bin/utilities/bashlib'
REGISTRY='s2.ubuntu.home:5000'

# Use the Unofficial Bash Strict Mode
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

sudo rm -rf ~/tmp
create_registry_defs ~/tmp '1.25' $(registry_refs)
