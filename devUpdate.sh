#!/bin/bash

#----------------------------------------------------------------------------
# calculate the elapsed time for an event
function timer.fmt_elapsed()
{
    local -ir elapsed=${1:?"Input parameter 'elapsed' must be passed to 'function ${FUNCNAME[0]}()'"}

    printf '%02d:%02d:%02d' $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60))
}  
#----------------------------------------------------------------------------
# log elapse time result 
function timer.log_elapsed()
{
    local -r name=${1:?"Input parameter 'name' must be passed to 'function ${FUNCNAME[0]}()'"}
    local -ir elapsed=${2:?"Input parameter 'elapsed' must be passed to 'function ${FUNCNAME[0]}()'"}
    
    printf "Time elapsed (%s): %s" "$name" "$(timer.fmt_elapsed $elapsed)"
} 
#----------------------------------------------------------------------------
# get the timestamp of a file in seconds
function timer.getTimestamp()
{
    local -r tfile=$(mktemp /tmp/foo.XXXXXXXXX)
    stat -c %Y "$tfile"
    rm "$tfile"
}  
#----------------------------------------------------------------------------


declare -i start_tm=$( timer.getTimestamp ) 
    
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

declare -i finish_tm=$( timer.getTimestamp ) 
declare -i elapsed_tm=$((finish_tm - start_tm)) 
declare fmt_tm=$( timer.fmt_elapsed $elapsed_tm )

printf "Time elapsed: %s\n" "$fmt_tm" 
