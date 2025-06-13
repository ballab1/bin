#!/bin/bash

if [ ! -f ~/GIT/Soho-Ball.certs/Soho-Ball_CA/certs.tgz ]; then
    echo 'unable to find ~/GIT/Soho-Ball.certs/Soho-Ball_CA/certs.tgz'
    ls -l ~/GIT/Soho-Ball.certs/Soho-Ball_CA/
    exit
fi

while read -r f; do
    sudo rm "/etc/ssl/certs/$f"
done < <(ls -l /etc/ssl/certs/ | grep 'Ball' | cut -d ' ' -f 13)
sudo find /usr/local/share/ca-certificates/soho-ball/ -type f -delete
sudo update-ca-certificates

find ~/.inf/ssl -type f -delete
find -mindepth 1 -maxdepth 1 ~/GIT/support/logs/ -type f -delete
find ~/production/workspace.production/.secrets -delete
[ -f ~/Downloads/certs.tgz ] && rm ~/Downloads/certs.tgz

cd ~/.inf/ssl
tar xvzf ~/GIT/Soho-Ball.certs/Soho-Ball_CA/certs.tgz
sudo cp SohoBall_CA.crt /usr/local/share/ca-certificates/soho-ball/
cp ~/GIT/Soho-Ball.certs/Soho-Ball_CA/certs.tgz ~/Downloads/
cd /usr/local/share/ca-certificates/soho-ball/
sudo update-ca-certificates

cd ~/production
deploy down

cd ~/GIT/support
build.sh -f jenkins
docker system prune -f -a

cd ~/production
CONTAINER_TAG=dev deploy

