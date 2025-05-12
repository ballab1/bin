#!/bin/bash

cd ~/production
deploy down
rm -rf workspace.production/.secrets
cd ~/.inf/ssl
tar cvzf ~/Downloads/certs.tgz *
cd ~/GIT/support
rm logs/*
build.sh -f jenkins
docker system prune -f -a
cd ~/production
rm -rf workspace.production/.secrets/
CONTAINER_TAG=dev deploy

