#!/bin/bash

#-----------------------------------------------------------------------------------------------
function fileData() {

    local file="$(basename $1)"

    local name="$(basename "$file")"
    local folder="$(cd "$(dirname "$file")"; pwd)"
    name="${name//\"/\\\"}"
    folder="${folder//\"/\\\"}"

    local -A stat_vals
    eval "stat_vals=( $(stat --format="['mount_point']='%m' ['time_of_birth']='%w'" "$1") )"
    local mount_source="$(grep -E '\s'"${stat_vals['mount_point']}"'\s' /etc/fstab | awk '{print $1}')"

    local tob="${stat_vals['time_of_birth']}"
    [ "$tob" = '-' ] && tob='unknown'

    echo -n '{"name":"'"$name"'",' \
            '"folder":"'"$folder"'",' \
            '"mount_point":"'"${stat_vals['mount_point']}"'",' \
            '"mount_source":"'"$mount_source"'",'

    if [ -h "$file" ]; then
        local ref2="$(readlink -f "$file" 2>/dev/null ||:)"
        if [ "${ref2:-}" ]; then
            echo -n '"symlink_reference":"'"$ref2"'",'
        else
            echo -n '"symlink_reference":null,'
            local ref="$(stat --format='%N' "$file" | awk '{print  substr($3,2,length($3)-2) }')"
            echo -n '"link_reference":"'"$ref"'",'
        fi
    fi
    [ -f "$file" ] && echo -n '"sha256":"'"$( sha256sum -b "$file" | cut -d ' ' -f 1 )"'",'

    local -a fields=( '"size":%s,'
                      '"blocks":%b,'
                      '"block_size":%B,'
                      '"xfr_size_hint":%o,'
                      '"device_number":%d,'
                      '"file_type":"%F",'
                      '"uid":%u,'
                      '"uname":"%U",'
                      '"gid":%g,'
                      '"gname":"%G",'
                      '"access_rights":"%a",'
                      '"access_rights__HRF":"%A",'
                      '"inode":%i,'
                      '"hard_links":%h,'
                      '"raw_mode":"0x%f",'
                      '"device_type":"0x%t:0x%T",'
                      '"file_created":%W,'
                      '"file_created__HRF":"'"$tob"'",'
                      '"last_access":%X,'
                      '"last_access__HRF":"%x",'
                      '"last_modified":%Y,'
                      '"last_modified__HRF":"%y",'
                      '"last_status_change":%Z,'
                      '"last_status_change__HRF":"%z"}\n' )

    stat --printf="$(echo ${fields[*]})" "$file"
}

#-----------------------------------------------------------------------------------------------
function old_fileData() {

    echo -n '{'
    json.encodeField "name"                                               "$(basename "$(stat --format='%n' "$1")")" 'string'
    echo -n ','
    json.encodeField "folder"                                             "$(cd "$(dirname "$1")"; pwd)" 'string'
    #  decode this to real mountpoint. Also remove this string from 'folder' and add real mount point without host.
    #  unless, mountpoint is local in which case host is fqdn
    echo -n ','
    local mount_point="$(grep -E '\s'"$(stat --format='%m' "$1")"'\s' /etc/fstab | awk '{print $1}')"
    json.encodeField "mount_point"                                        "$mount_point" 'string'
    if [ -h "$1" ]; then
        echo -n ','
        json.encodeField "link_reference"                                 "$(readlink -f "$1" )" 'string'
    fi
    if [ -f "$1" ]; then
        echo -n ','
        json.encodeField "sha256"                                         "$( sha256sum -b "$1" | awk '{ print $1 }' )" 'string'
    fi

    echo -n ','
    json.encodeField "size"                                               "$(stat --format='%s' "$1")" 'integer'
    echo -n ','
    json.encodeField "blocks"                                             "$(stat --format='%b' "$1")" 'integer'
    echo -n ','
    json.encodeField "block_size"                                         "$(stat --format='%B' "$1")" 'integer'
    echo -n ','
    json.encodeField "xfr_size_hint"                                      "$(stat --format='%o' "$1")" 'integer'
    echo -n ','
    json.encodeField "device_number"                                      "$(stat --format='%d' "$1")" 'integer'
    echo -n ','
    json.encodeField "file_type"                                          "$(stat --format='%F' "$1")" 'string'
    echo -n ','
    json.encodeField "uid"                                                "$(stat --format='%u' "$1")" 'string'
    echo -n ','
    json.encodeField "uname"                                              "$(stat --format='%U' "$1")" 'string'
    echo -n ','
    json.encodeField "gid"                                                "$(stat --format='%g' "$1")" 'string'
    echo -n ','
    json.encodeField "gname"                                              "$(stat --format='%G' "$1")" 'string'
    echo -n ','
    json.encodeField "access_rights"                                      "$(stat --format='%a' "$1")" 'string'
    echo -n ','
    json.encodeField "access_rights__HRF"                                 "$(stat --format='%A' "$1")" 'string'
    echo -n ','
    json.encodeField "inode"                                              "$(stat --format='%i' "$1")" 'integer'
    echo -n ','
    json.encodeField "hard_links"                                         "$(stat --format='%h' "$1")" 'integer'
    echo -n ','
    json.encodeField "raw_mode"                                           "$(stat --format='0x%f' "$1")" 'string'
    echo -n ','
    json.encodeField "device_type"                                        "$(stat --format='0x%t:0x%T' "$1")" 'string'

    local tob="$(stat --printf='%w' "$1")"
    [ "$tob" = '-' ] && tob='unknown'
    echo -n ','
    json.encodeField "file_created"                                       "$(stat --format='%W' "$1")" 'integer'
    echo -n ','
    json.encodeField "file_created__HRF"                                  "$tob" 'string'
    echo -n ','
    json.encodeField "last_access"                                        "$(stat --format='%X' "$1")" 'integer'
    echo -n ','
    json.encodeField "last_access__HRF"                                   "$(stat --format='%x' "$1")" 'string'
    echo -n ','
    json.encodeField "last_modified"                                      "$(stat --format='%Y' "$1")" 'integer'
    echo -n ','
    json.encodeField "last_modified__HRF"                                 "$(stat --format='%y' "$1")" 'string'
    echo -n ','
    json.encodeField "last_status_change"                                 "$(stat --format='%Z' "$1")" 'integer'
    echo -n ','
    json.encodeField "last_status_change__HRF"                            "$(stat --format='%z' "$1")" 'string'
    echo '}'
}
#-----------------------------------------------------------------------------------------------
function test0() {
    local fileList="${PROGRAM_DIR}/files.txt"
    local file t1 t2 t3

    t1=$(timer.getTimestamp)
    while read -r file; do
        fileData "$file" >/dev/null
    done < "$fileList"

    t2=$(timer.getTimestamp)
    while read -r file; do
        old_fileData "$file" >/dev/null
    done < "$fileList"

    t3=$(timer.getTimestamp)
    timer.logElapsed 'filedata: ' $(( t2 - t1 ))
    echo
    timer.logElapsed 'old_fileData: ' $(( t3 - t2 ))
    echo

# 1/18/20 results
# Time elapsed (filedata: ): 00:01:45
# Time elapsed (old_fileData: ): 00:03:56
}
#-----------------------------------------------------------------------------------------------
function test1() {
    local file
    local -i i=0
    for file in "$@"; do
#        [[ $(( i++ )) -ge 9 || $i -le 10 ]] || continue
        fileData "$file"
    done
}
#-----------------------------------------------------------------------------------------------
function test2() {

    cd '/mnt/Synology/Guest/All Users/Music/Barenaked Ladies/Rock Spectacle/'
    fileData '11 If I Had $1000000.wma'
}
#-----------------------------------------------------------------------------------------------

declare -r PROGRAM_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

declare -r loader="${PROGRAM_DIR}/../utilities/appenv.bashlib"
if [ ! -e "$loader" ]; then
    echo 'Unable to load libraries' >&2
    exit 1
fi
source "$loader"
appenv.loader 'artifactory.search'

#test1 '/mnt/Synology/Guest/All Users/Music/Barenaked Ladies/Rock Spectacle'/*
#test2
#(cd '/mnt/Synology/Guest/All Users/Music/Jojo/Jojo'; test1 *)
#(cd '/mnt/Synology/Guest/Documents/20151017_100615'; test1 *)
#(cd '/home/bobb/.bin/test';
# touch 'this is a quoted "string", isn'"'"'t it'
# test1 *
# rm 'this is a quoted "string", isn'"'"'t it'
#)
(cd '/home/bobb/xsrc'; test1 *)
