#!/bin/bash

declare -r SRC=/mnt/ubuntu/archive/docker
declare -r ORG=${SRC}/org


function ::update_docker() {
    local org="${1:?}"
    sudo cp "${org}/daemon.json" /etc/docker/daemon.json
    sudo chmod 644 /etc/docker/daemon.json
    sudo systemctl restart docker
    sudo systemctl status docker
}

function ::update_registry() {
    local org="${1:?}"
    sudo cp "${org}/config.yml" /etc/docker/registry/config.yml
    sudo chmod 644 /etc/docker/registry/config.yml
    sudo cp "${org}/htpasswd" /etc/docker/registry/htpasswd
    sudo chmod 644 /etc/docker/registry/htpasswd
    sudo systemctl restart docker-registry
    sudo systemctl status docker-registry
}

declare origin="$SRC"
declare -r arg="${1:-src}"
[ "${arg,,}" = 'org' ] && origin="$ORG"

case "$(hostname)" in
  s2.ubuntu.home)
    ::update_registry "$origin"
    ;;
  *)
    ::update_docker "$origin"
    ;;
esac

