#!/bin/bash

declare -r dir='archive/yyyy'
declare file line commit tm

rm -rf "$dir"
mkdir -p "$dir"
while read -r line;do
  #shellcheck disable=SC2076
  [[ "$line" =~ "git reflog | grep ':git keep:'" ]] && continue
  commit="$(echo "$line" | cut -d ' ' -f 1)"
  tm="$(echo "$line" | awk '{split($0,arr," HEAD.*keep: "); print arr[2]}')"
  tm="$(date --date="$tm" '+%Y%m%dT%H%M%S')"

  git reset --hard "$commit"

  for file in 'Docker' 'docker-compose.yml' 'package-lock.json' 'package.json' 'server.js'; do
    [ -f "$file" ] && cp "$file" "${dir}/${tm}.${commit}.${file}"
    [ -f "ci\$file" ] && cp "$file" "${dir}/${tm}.${commit}.${file}"
    [ -f "public\$file" ] && cp "$file" "${dir}/${tm}.${commit}.${file}"
  done
done < <(git-keep --history)

git reset --hard origin/main
ls "$dir"
