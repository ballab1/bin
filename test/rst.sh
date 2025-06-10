#!/bin/bash

rm *.log

docker tag s2.ubuntu.home:5000/alpine/jenkins/2.462.1:main s2.ubuntu.home:5000/alpine/jenkins/2.462.1:dev
docker rmi s2.ubuntu.home:5000/alpine/jenkins/2.462.1:main
docker rmi s2.ubuntu.home:5000/alpine/jenkins/2.462.1:d61a921c54fc526f4c9069e34bf8c91fe98999df7fc4e2fc957143d7d35d9ddd
docker-utilities delete --no_confirm_delete alpine/jenkins/2.462.1:dev
docker push s2.ubuntu.home:5000/alpine/jenkins/2.462.1:dev
echo 'alpine/jenkins/2.462.1'; docker-utilities report --tags alpine/jenkins/2.462.1
echo

docker pull s2.ubuntu.home:5000/alpine/openjdk/17.0.12_p7-r0:dev
docker-utilities delete --no_confirm_delete alpine/openjdk/17.0.12_p7-r0:dev
docker push s2.ubuntu.home:5000/alpine/openjdk/17.0.12_p7-r0:dev
docker rmi s2.ubuntu.home:5000/alpine/openjdk/17.0.12_p7-r0:dev
docker rmi s2.ubuntu.home:5000/alpine/openjdk/17.0.12_p7-r0:main
docker rmi s2.ubuntu.home:5000/alpine/openjdk/17.0.12_p7-r0:aa81ac92eb64c78b2a6f4b5e0402be1b32fcf4a8e882efdedf99eae690e17ea6
echo 'alpine/openjdk/17.0.12_p7-r0'; docker-utilities report --tags alpine/openjdk/17.0.12_p7-r0
echo

docker pull s2.ubuntu.home:5000/alpine/base_container:dev
docker-utilities delete --no_confirm_delete alpine/base_container:dev
docker push s2.ubuntu.home:5000/alpine/base_container:dev
docker rmi s2.ubuntu.home:5000/alpine/base_container:dev
docker rmi s2.ubuntu.home:5000/alpine/base_container:main
docker rmi s2.ubuntu.home:5000/alpine/base_container:ff6d4a8d2487e74cd7393eb9a726a5669f8f11ea75d3abfcb1c66bab1dcc6114
echo 'alpine/base_container'; docker-utilities report --tags alpine/base_container
echo

docker tag s2.ubuntu.home:5000/alpine/nginx-proxy/1.26.1:main s2.ubuntu.home:5000/alpine/nginx-proxy/1.26.1:dev
docker rmi s2.ubuntu.home:5000/alpine/nginx-proxy/1.26.1:main
docker rmi s2.ubuntu.home:5000/alpine/nginx-proxy/1.26.1:f0b9b3419ae50463df214428c8d488d4e4e1f0f684e7c962eb505426c1d3081b
docker-utilities delete --no_confirm_delete alpine/nginx-proxy/1.26.1:dev
docker push s2.ubuntu.home:5000/alpine/nginx-proxy/1.26.1:dev
echo 'alpine/nginx-proxy/1.26.1'; docker-utilities report --tags alpine/nginx-proxy/1.26.1
echo

docker pull s2.ubuntu.home:5000/alpine/nginx-base/1.26.1:dev
docker-utilities delete --no_confirm_delete alpine/nginx-base/1.26.1:dev
docker push s2.ubuntu.home:5000/alpine/nginx-base/1.26.1:dev
docker rmi s2.ubuntu.home:5000/alpine/nginx-base/1.26.1:dev
docker rmi s2.ubuntu.home:5000/alpine/nginx-base/1.26.1:main
docker rmi s2.ubuntu.home:5000/alpine/nginx-base/1.26.1:1776daa4dd9a5fe9505d2b96589a024103b61aaba394886cd24f81b72fc23b5e
echo 'alpine/nginx-base/1.26.1'; docker-utilities report --tags alpine/nginx-base/1.26.1
echo

docker pull s2.ubuntu.home:5000/alpine/supervisord:dev
docker-utilities delete --no_confirm_delete alpine/supervisord:dev
docker push s2.ubuntu.home:5000/alpine/supervisord:dev
docker rmi s2.ubuntu.home:5000/alpine/supervisord:dev
docker rmi s2.ubuntu.home:5000/alpine/supervisord:main
docker rmi s2.ubuntu.home:5000/alpine/supervisord:75e3e2d9c86d7cb747dc36fad65dd935714a12e899375eabe1781f865672fb9f
echo 'alpine/supervisord'; docker-utilities report --tags alpine/supervisord
echo

docker tag s2.ubuntu.home:5000/alpine/webdav:main s2.ubuntu.home:5000/alpine/webdav:dev
docker rmi s2.ubuntu.home:5000/alpine/webdav:main
docker rmi s2.ubuntu.home:5000/alpine/webdav:1ea85346ec4ff060fe94b18ff1a50b98cfb0389b578f6697e30f996d0ef58c36
docker-utilities delete --no_confirm_delete alpine/webdav:dev
docker push s2.ubuntu.home:5000/alpine/webdav:dev
echo 'alpine/webdav'; docker-utilities report --tags alpine/webdav
echo

docker rmi s2.ubuntu.home:5000/docker.io/alpine:3.18.8

docker-utilities show --images

cd ~/production/workspace.production/.versions
git checkout main
git reset --hard 1c9b1c6e95473b9154ae56509062448ee19c62bd
git push -f
git checkout dev

cd ~/production
git checkout main
git reset --hard 2e14c86db82fc7635db4c30c734a28a4a9e03de2
git push -f
git checkout dev
