#!/bin/bash

declare -a kafka_hosts=( 's3.ubuntu.home' 's7.ubuntu.home' 's8.ubuntu.home' )
declare -a kafka_ports=( 7202 7204 9999 )
declare -a unix_hosts=( 's2.ubuntu.home' 's3.ubuntu.home' 's4.ubuntu.home' 'nas.home' 'wdmycloud.home' 'pi.ubuntu.home' )
declare -a unix_ports=( 9100 )
declare -a windows_hosts=( 'ballantyne.home' )
declare -a windows_ports=( 9182 )
declare -a jenkins_hosts=( 'jenkins-exporter.jenkins-exporter.svccluster.local' )
declare -a jenkins_ports=( 9182 )
declare -a minio_hosts=( 's1.ubuntu.home' )
declare -a minio_ports=( 9000 )

declare -a scans=( 'kafka' 'unix' 'windows' 'jenkins' 'minio' )



function scanHosts() {
    local -r hostsName="${1:?}"
    local -r portsName="${2:?}"

    local hostsArray="${hostsName}[@]"
    local portsArray="${portsName}[@]"

    for host in "${!hostsArray}"; do
        for port in "${!portsArray}"; do
            local file="${host}.${port}"
            curl "http://${host}:${port}/metrics" > "$file"
        done
    done
}



for scan in "${scans[@]}"; do
    scanHosts "${scan}_hosts" "${scan}_ports"
done
