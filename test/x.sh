#!/bin/bash

function build.logImageInfo()
{
    local -r image=${1:?}
    local containerOS="${image#*/}"
    containerOS="${containerOS%/*}"

    local json="$(docker inspect "$image" | jq '.[].Config.Labels')"
    local depLog="${containerOS}.dependencies.log"
    [ -e "$depLog" ] || touch "$depLog"

    printf '%s :: pulling %s\n' "$(TZ='America/New_York' date)" "$image" >> "$depLog"
    echo '    refs:           '$(jq '."container.git.refs"' <<< "$json") >> "$depLog"
    echo '    commitId:       '$(jq '."container.git.commit"' <<< "$json") >> "$depLog"
    echo '    repo:           '$(jq '."container.git.url"' <<< "$json") >> "$depLog"
    echo '    fingerprint:    '$(jq '."container.git.fingerprint"' <<< "$json") >> "$depLog"
    echo '    revision:       '$(jq '."container.origin"' <<< "$json") >> "$depLog"
    echo '    original.name:  '$(jq '."container.original.name"' <<< "$json") >> "$depLog"
    printf '\n\n\n' >> "$depLog"
}

build.logImageInfo "$@"

$ for f in $(find . -name 'docker-compose.yml') ; do  sed -E -i -e 's|(container.original.name.*)$|\1\n                container.parent: $CONTAINER_PARENT|' $f;done
