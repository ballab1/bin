#!/bin/bash

# https://ubunlog.com/en/crea-tu-almacenamiento-privado-al-estilo-aws-s3-con-minio-en-ubuntu/

#----------------------------------------------------------------------------
function minio.install()
{
    # download and install the binary 
    useradd --system minio-user --shell /sbin/nologin
    curl -O https://dl.minio.io/server/minio/release/linux-amd64/minio
    mv minio /usr/local/bin
    chmod +x /usr/local/bin/minio
    chown minio-user:minio-user /usr/local/bin/minio

    #  ensure minios starts with system reboot
    mkdir /usr/local/share/minio
    mkdir /etc/minio
    chown minio-user:minio-user /usr/local/share/minio
    chown minio-user:minio-user /etc/minio

    # create /etc/default/minio for options
    cat < EOF > /etc/default/minio
MINIO_VOLUMES="/usr/local/share/minio/"
MINIO_OPTS="-C /etc/minio --address s3-minio.home:443"
EOF

    setcap 'cap_net_bind_service=+ep' /usr/local/bin/minio
    curl -O https://raw.githubusercontent.com/minio/minio-service/master/linux-systemd/minio.service
    mv minio.service /etc/systemd/system
    systemctl daemon-reload
    systemctl enable minio

    # implement the TLS certificates with certbot
    apt update
    apt install -y software-properties-common
    add-apt-repository ppa:certbot/certbot
    apt update
    apt install -y certbot
    certbot certonly --standalone -d ts3-minio.home --staple-ocsp -m tu@correoelectronico.com --agree-tos
    cp /etc/letsencrypt/live/minio.ranvirslog.com/fullchain.pem /etc/minio/certs/public.crt
    cp /etc/letsencrypt/live/minio.ranvirslog.com/privkey.pem /etc/minio/certs/private.key
    chown minio-user:minio-user /etc/minio/certs/public.crt
    chown minio-user:minio-user /etc/minio/certs/private.key

    # start the service and check that everything is working correctly
    service minio start     
    service minio status
    
    # enter the domain or subdomain that you assigned to minio from your web browser "https://s3-minio.home"
}

#----------------------------------------------------------------------------
function minio.usage() {
    echo
    echo "$PROGNAME -  available functions:"
    local -a methods
    mapfile -t methods < <(minio.functions)
    printf '    %s\n' "${methods[@]}"
    echo
}

##################################################################################################
#
#      MAIN
#
##################################################################################################

# Use the Unofficial Bash Strict Mode
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

declare -r PROGNAME="$(basename "${BASH_SOURCE[0]}")"
declare -r PROGRAM_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" 

if [ $# -eq 0 ] || [[ "${1,,}" = *help ]] || [[ "${1,,}" = *usage ]]; then
    minio.usage
    exit
fi

# always run as root
if [ ${EUID:-0} -ne 0 ]; then
    sudo --preserve-env "$0" "$@"
    rm "$USER_INFO_FILE"
    exit
fi

export PATH="${PATH}:${HOME}/.bin"
[ -e "${PROGRAM_DIR}/trap.bashlib" ] && source "${PROGRAM_DIR}/trap.bashlib"

minio.install "$@"
