#!/bin/bash

function main() {
  while read -r f; do
    [ -f "${f}/31.Secret.yml" ] && process "$f"
  done < <(find . -name '*Deploy*' | cut -d '/' -f 2)
}

function process() {
  local dir="${1:?}"

  local secret="${dir}/31.Secret.yml"
  sed -i -e "s|namespace: postgres|namespace: ${dir}|" "$secret"

  local deploy="$(find "$dir" -name '*Deploy*')"
  [ "$(grep -c 'name: regcred' "$deploy")" -gt 0 ] && return
  awk '/dnsPolicy: ClusterFirst/ {
    print;
    print "      imagePullSecrets:";
    print "        - name: regcred";
    next
  } 1' "$deploy" > Deployment.patched.yml
  mv Deployment.patched.yml "$deploy"
}

main