#!/usr/bin/bash


declare VERSION=2.17.3
declate -A apps=( ["docker-compose"]="'docker/compose' '2.17.3'"
                  ["grr"]="'grafana/grizzly' '0.2.0'"
                  ["jb"]="'jsonnet-bundler' '0.5.1'"
                  ["tk"]="'grafana/tanka' '0.23.0'"
                )

function installApp() {
    local app='docker-compose'
    local remote='docker/compose'
    local version='2.17.3'

    # download update
    local target="/usr/local/bin/${app}.${version}"
    curl --silent --location https://github.com/${remote}/releases/download/v${version}/${app}-${OS}-${HW} -o "$target"
    [ "$?" -eq 0 ] || exit 1
    [ "$(stat -c %s "$target")" -gt 100 ] || exit 1
    chmod 755 "$target"
    
    # create/update symlink
    app="/usr/bin/${app}"
    [ -e "$app" ] && rm "$app"
    ln -s "$target" "$app"
}


declare HW="$(uname -m)"
declare OS="$(uname -s)"
declare re='^\d+\.\d+\.\d+$'

# do not run on pi or s2
[ "$HW" = 'x86_64' ] || exit

 # if provided with 'all' parameter
if [ "$#" -gt 0 ]; then
   if [[ "$1" =~ $re ]]; then
     VERSION="$1"

   elif [ "$1" = 'all' ]; then
     declare cmd="$(readlink -f "$0")"
     for h in pi s{1..8};do
       echo "$h.ubuntu.home"
       ssh "$h.ubuntu.home" "$cmd"
     done
     exit
   fi
fi

# ensure this script is run as root
if [[ $EUID != 0 ]]; then
  sudo --preserve-env "$0" "$@"
  exit
fi

