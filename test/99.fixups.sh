#!/bin/bash

# Use the Unofficial Bash Strict Mode
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

declare -ra exceptions=(''
                         /
                         /dev
                         /etc
                         /lib
                         /lib64
                         /proc
                         /root
                         /run
                         /sbin
                         /sys
                         /usr/bin
                         /usr/local/bin
                         /usr/local/crf/startup
                         /var/run
                        )

declare -a fixup_dirs=( /var/log ) # always fixup the log dir
[ "${FIXUPDIRS:-}" ] && fixup_dirs+=( "${FIXUPDIRS[@]}" )                 # use 'FIXUPDIRS' from scripted code

# BASH does not have ability to export arrays : FIXUPDIRS is internal and can be set. CBF_FIXUPDIRS is external so need to use a file
[[ "${CBF_FIXUPDIRS:-}" && -e "${CBF_FIXUPDIRS:-}" ]] && fixup_dirs+=( $(< "$CBF_FIXUPDIRS") )

declare dir ex
for dir in "${fixup_dirs[@]}"; do
    [ -z "${dir:-}" ] && continue
    for ex in "${exceptions[@]}"; do
        if [ "$dir" = "$ex" ]; then
            echo -e '\e[33m'"setting of '$dir' not permitted. Ignoring"'\e[0m'
            continue 2
        fi
    done
    echo "crf.fixupDirectory $dir"
done
