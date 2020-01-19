#!/bin/bash

#-----------------------------------------------------------------------------------------------
function fileData_1() {

    echo -n '{'
    json.encodeField "name"                    "$(basename "$(stat --format='%n' "$1")")" 'string'
    echo -n ','
    json.encodeField "folder"                  "$(cd "$(dirname "$1")"; pwd)" 'string'

    #  decode this to real mountpoint. Also remove this string from 'folder' and add real mount point without host.
    #  unless, mountpoint is local in which case host is fqdn
    local mount_point="$(stat --format='%m' "$1")"
    mount_point="$(grep -E '\s'"$mount_point"'\s' /etc/fstab | awk '{print $1}')"

    echo -n ','
    json.encodeField "mount_point"         "$mount_point" 'string'

    if [ -h "$1" ]; then
        echo -n ','
        json.encodeField "link_reference"      "$(readlink -f "$1" )" 'string'
    fi
    if [ -f "$1" ]; then
        echo -n ','
        json.encodeField "sha256"              "$( sha256sum -b "$1" | awk '{ print $1 }' )" 'string'
    fi
    echo -n ','
    json.encodeField "size"                    "$(stat --format='%s' "$1")" 'integer'
    echo -n ','
    json.encodeField "blocks"                  "$(stat --format='%b' "$1")" 'integer'
    echo -n ','
    json.encodeField "block_size"              "$(stat --format='%B' "$1")" 'integer'
    echo -n ','
    json.encodeField "xfr_size_hint"           "$(stat --format='%o' "$1")" 'integer'
    echo -n ','
    json.encodeField "device_number"           "$(stat --format='%d' "$1")" 'integer'
    echo -n ','
    json.encodeField "file_type"               "$(stat --format='%F' "$1")" 'string'
    echo -n ','
    json.encodeField "uid"                     "$(stat --format='%u' "$1")" 'integer'
    echo -n ','
    json.encodeField "uname"                   "$(stat --format='%U' "$1")" 'string'
    echo -n ','
    json.encodeField "gid"                     "$(stat --format='%g' "$1")" 'integer'
    echo -n ','
    json.encodeField "gname"                   "$(stat --format='%G' "$1")" 'string'
    echo -n ','
    json.encodeField "access_rights"           "$(stat --format='%a' "$1")" 'string'
    echo -n ','
    json.encodeField "access_rights__HRF"      "$(stat --format='%A' "$1")" 'string'
    echo -n ','
    json.encodeField "inode"                   "$(stat --format='%i' "$1")" 'integer'
    echo -n ','
    json.encodeField "hard_links"              "$(stat --format='%h' "$1")" 'integer'
    echo -n ','
    json.encodeField "raw_mode"                "$(stat --format='0x%f' "$1")" 'string'
    echo -n ','
    json.encodeField "device_type"             "$(stat --format='0x%t:0x%T' "$1")" 'string'

    local tob="$(stat --printf='%w' "$1")"
    [ "$tob" = '-' ] && tob='unknown'
    echo -n ','
    json.encodeField "file_created"            "$(stat --format='%W' "$1")" 'integer'
    echo -n ','
    json.encodeField "file_created__HRF"       "$tob" 'string'
    echo -n ','
    json.encodeField "last_access"             "$(stat --format='%X' "$1")" 'integer'
    echo -n ','
    json.encodeField "last_access__HRF"        "$(stat --format='%x' "$1")" 'string'
    echo -n ','
    json.encodeField "last_modified"           "$(stat --format='%Y' "$1")" 'integer'
    echo -n ','
    json.encodeField "last_modified__HRF"      "$(stat --format='%y' "$1")" 'string'
    echo -n ','
    json.encodeField "last_status_change"      "$(stat --format='%Z' "$1")" 'integer'
    echo -n ','
    json.encodeField "last_status_change__HRF" "$(stat --format='%z' "$1")" 'string'
    echo '}'
}

#-----------------------------------------------------------------------------------------------
function fileData_0() {

    declare -A stat_vals
    eval "stat_vals=( $(stat --format="['file_name']="'"%n"'" ['mount_point']='%m' ['time_of_birth']='%w'" "$1") )"
    local mount_point="$(grep -E '\s'"${stat_vals['mount_point']}"'\s' /etc/fstab | awk '{print $1}')"

    local tob="${stat_vals['time_of_birth']}"
    [ "$tob" = '-' ] && tob='unknown'

    local file="${stat_vals['file_name']}"

    echo -n '{"name":"'"$(basename "$file")"'",' \
            '"folder":"'"$(cd "$(dirname "$file")"; pwd)"'",' \
            '"mount_point":"'"$mount_point"'",'

    [ -h "$file" ] && echo -n '"link_reference":'"$(readlink -f "$file" )"'",'
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
                      '"last_status_change__HRF":"%z"}' )

    (IFS='' stat --format="${fields[*]}" "$file")
}

declare -r PROGRAM_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

declare -r loader="${PROGRAM_DIR}/../utilities/appenv.bashlib"
if [ ! -e "$loader" ]; then
    echo 'Unable to load libraries' >&2
    exit 1
fi
source "$loader"
appenv.loader 'artifactory.search'


declare fileList="${PROGRAM_DIR}/files.txt"
declare t1 t2 t3

t1=$(timer.getTimestamp)
while read -r file; do
    fileData_0 "$file" >/dev/null
#    jq '.' <(fileData_0 "$file")
#    break
done < "$fileList"

t2=$(timer.getTimestamp)
while read -r file; do
    fileData_1 "$file" >/dev/null
#    jq '.' <(fileData_1 "$file")
#    break
done < "$fileList"

t3=$(timer.getTimestamp)
timer.logElapsed 'filedata_0: ' $(( t2 - t1 ))
echo
timer.logElapsed 'filedata_1: ' $(( t3 - t2 ))
echo

# 1/18/20 results
# Time elapsed (filedata_0: ): 00:01:45
# Time elapsed (filedata_1: ): 00:03:56

