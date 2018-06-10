#!/bin/bash

declare start=$(tfile=$(mktemp); stat -c %Y "$tfile"; rm "$tfile" )
export  CONTAINER_TAG="$( date +%Y%m%d )"
export  CBF_VERSION=dev
set -o verbose

cd ~/support

docker-compose build php5
docker-compose build php7

cd ~/prod
docker-compose build nagios
docker-compose build nginx
docker-compose build phpadmin
docker-compose build zen
docker-compose build smonitor

#docker-compose down
#roc
#docker-compose up -d

set +o verbose
declare finish=$(tfile=$(mktemp); stat -c %Y "$tfile"; rm "$tfile" )
declare -i elapsed=$(( finish - start ))
printf "Time elapsed: %02d:%02d:%02d\n"  $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60)) 

