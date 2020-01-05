#!/bin/bash

declare cmd="${1:-docker run --rm --entrypoint '' alpine cat /etc/resolv.conf | sed '1,12 d'}"

declare -i i
declare -a result
for i in {3..8};do
    echo -e '\n\e[33mubuntu-s'$i'\e[0m'
    mapfile -t result < <(ssh s$i "$cmd")
    printf '    %s\n' "${result[@]}"
done

