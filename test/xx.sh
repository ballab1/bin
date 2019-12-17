#!/bin/bash

x() {
  clear
  echo '============================================================================================================='
  echo $1
  cat $1
  echo
  echo
  echo
  read -n1 -s
}

x build_container/build/action_folders/05.applications/02.builder.alpine
x hubot/build/action_folders/07.run.startup/03.hubot.sh
x jenkins/build/action_folders/07.run.startup/05.jenkins.sh
x nagios/build/action_folders/06.post_build_mods/05.nagios
x nodervisor/build/action_folders/07.run.startup/03.nodervisor.sh
x webdav/build/action_folders/06.post_build_mods/02.config_WEBDAV

