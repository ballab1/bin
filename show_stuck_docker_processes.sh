#!/bin/bash

# find the processes that are stuck
for p in $(ps faux | grep -E '\_ /usr/bin/docker-proxy -proto tcp -host-ip ' | grep -v 'grep' | awk '{print $2}');do
    sudo cat "/proc/$p/mounts" | grep overlay
done | sed -E -e 's|[,=: ]|\n|g' | sed -E -e 's:/(fs|work|rootfs|diff|merged)$::' | sort -u | awk '{if (length($0) > 20){print $0}}' > overlay.txt

# show direcories that are stuck
sudo ls -l /var/lib/docker/overlay2/*-init

# show symlinks that are prokect
sudo ls -l /var/lib/docker/overlay2/1

# kill proceesses
for p in $(ps faux | grep -E '\_ /usr/bin/docker-proxy -proto tcp -host-ip ' | grep -v 'grep' | awk '{print $2}');do
    sudo kill -9 $p
done | sed -E -e 's|[,=: ]|\n|g' | sed -E -e 's:/(fs|work|rootfs|diff|merged)$::' | sort -u | awk '{if (length($0) > 20){print $0}}' > overlay.txt

