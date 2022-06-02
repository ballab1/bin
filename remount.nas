#!/bin/bash


if [ ${EUID:-0} -ne 0 ]; then
    # shellcheck disable=SC2046
    sudo --preserve-env "$0" "$@"
    exit
fi


declare target=/etc/fstab
declare -A mounts=( ['/mnt/ubuntu']='10.3.1.4:/volume1/ubuntu'
                      ['/mnt/GIT']='10.3.1.4:/volume1/GIT'
                      ['/mnt/k8s']='10.3.1.4:/volume1/K8S'
                      ["/home/bobb/src"]='10.3.1.4:/volume1/ubuntu'
                      ["/home/bobb/GIT"]='10.3.1.4:/volume1/GIT'
                    )

umount /mnt/GIT
umount /mnt/ubuntu
umount /mnt/k8s
umount /home/bobb/GIT
umount /home/bobb/src

for mnt in "${!mounts[@]}";do
    [ -d "$mnt" ] || mkdir -p "$mnt"
    sed -i "/${mnt//\//\\/} /d" "$target"
    printf '%s %s nfs rw,vers=4\n' "${mounts[$mnt]}" "${mnt}" >> "$target"
done
mount -a ||:
