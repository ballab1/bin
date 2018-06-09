#!/bin/bash

declare start=$(date +%s)
export  CONTAINER_TAG="${1:-$( date +%Y%m%d )}"
export  CBF_VERSION=dev
set -o verbose

cd ~/support

docker-compose build base
docker-compose build openjdk
docker-compose build supervisord
docker-compose build nginx_base
docker-compose build php5
docker-compose build php7

cd ~/prod
docker-compose build broker
#docker-compose build hubot
docker-compose build jenkins
docker-compose build mysql
docker-compose build nagios
docker-compose build nginx
docker-compose build phpadmin
docker-compose build webdav
docker-compose build zen
docker-compose build zookeeper
docker-compose build smonitor
docker-compose build kafkamgr

#docker-compose down
#roc
#docker-compose up -d

set +o verbose
declare finish=$(date +%s)
declare -i elapsed=$(( finish - start ))
printf "Time elapsed: %02d:%02d:%02d\n"  $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60)) 

