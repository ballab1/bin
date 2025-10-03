#!/bin/bash

set -o pipefail

start_time=$(date --utc +%FT%T.%6NZ)

end_time=$(date --utc +%FT%T.%6NZ)
T1=$(TZ=EST5EDT date -d "${end_time}" +%s)
T0=$(TZ=EST5EDT date -d "${start_time}" +%s)
duration=$((${T1}-${T0}))


broker='s3.ubuntu.home:9092,s7.ubuntu.home:9092,s8.ubuntu.home:9092'
KAFKA_JSON="
{
    \"uuid\": \"$(uuidgen --time)\",
    \"start_time\": \"$start_time\",
    \"end_time\": \"$end_time\",
    \"duration\": \"$(date -u -d @${duration} +%T)\",
    \"install_type\": \"aquaman\",
    \"host_info\": {
        \"cpus\": $(nproc),
        \"host_name\": \"$(hostname)\",
        \"memory\": $(free -g|awk '/^Mem:/{print $2}')
    }
}"

echo "$KAFKA_JSON" | sed s/\"\"/null/g | jq -c '.' | docker run -i --rm --network=host "${DOCKER_REGISTRY:-}docker.io/edenhill/kcat:1.7.1" -b "${broker}" -P -t 'test-events'
echo "$duration"
