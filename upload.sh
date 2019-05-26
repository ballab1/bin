#!/bin/bash

declare ARTIFACTORYUSER=svc_cyclonebuild
declare ARTIFACTORYPASSWORD=AP3NTbQYjxrPAiau4ABRiWcFiy4cAqxseJKimx

function die()
{
    echo -en "\e[93m" >&2
    echo -n "$*" >&2
    echo -e "\e[0m" >&2
}


function uploadFile()
{
    local -r target="${1:?}"

    local file=~/"Artifactory/$(basename "$target")"
    tar -czf "$file" container_build_framework

    local md5Value="$(md5sum "$file")"
    md5Value="${md5Value:0:32}"
    local sha1Value="$(sha1sum "$file")"
    sha1Value="${sha1Value:0:40}"
    
    local -r url="https://afeoscyc-mw.cec.lab.emc.com/artifactory/cyclone-devops/cyclone-devops/$target"
    
    echo "INFO: Uploading $file to $url"
    curl -k -X PUT -u $ARTIFACTORYUSER:$ARTIFACTORYPASSWORD \
         -H "X-Checksum-Md5: $md5Value" \
         -H "X-Checksum-Sha1: $sha1Value" \
         -T "$file" \
         $url 
}

[ -d container_build_framework ] || die 'No framework directory located'
[ -e container_build_framework/.git ] || die 'CBF is not a git directory'

declare tarFile="$(cd container_build_framework; git describe --tags).tar.gz"
uploadFile "container_build_framework/$tarFile"

