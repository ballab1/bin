#!/bin/bash


if [ ${EUID:-0} -ne 0 ]; then
    # shellcheck disable=SC2046
    sudo --preserve-env "$0" "$@"
    exit
fi

# find procs which cause 'busy' and kill them
#for p in $(lsof | GIT | awk '{print $2}');do kill "$p";done




declare -A mounts=( ['/mnt/ubuntu']='10.3.1.4:/volume1/ubuntu'
                    ['/mnt/GIT']='10.3.1.4:/volume1/GIT'
                    ['/mnt/k8s']='10.3.1.4:/volume1/K8S'
                    ['/mnt/Registry']='10.3.1.4:/volume1/Docker-Registry'
                    ["/home/bobb/src"]='10.3.1.4:/volume1/ubuntu'
                    ["/home/bobb/GIT"]='10.3.1.4:/volume1/GIT'
                  )
declare target=/etc/fstab


for mnt in "${!mounts[@]}";do
    [ "$(find "$(dirname "$mnt")" -maxdepth 1 -mindepth 1 -name "$(basename "$mnt")" 2>/dev/null)" ] || continue
    umount "$mnt"
done


for mnt in "${!mounts[@]}";do
    [ "$(find "$(dirname "$mnt")" -maxdepth 1 -mindepth 1 -name "$(basename "$mnt")" 2>/dev/null)" ] || continue
    sed -i "/${mnt//\//\\/} /d" "$target"
    printf '%s %s nfs rw,vers=4\n' "${mounts[$mnt]}" "${mnt}" >> "$target"
done
mount -a ||:
