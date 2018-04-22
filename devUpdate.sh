#!/bin/bash

cd ~/support.dev
docker-compose build base
docker-compose build openjdk
docker-compose build supervisord
docker-compose build php5

cd ~/prod
docker-compose build broker
docker-compose build hubot
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
