#!/bin/bash

function ts()
{
  local ln="${1:?}"
  date --date="${ln:0:16}" +'%s'
}

function showlines()
{
  if [ $start -gt $end ]; then
    tm=$start
    start=$end
    end=$tm
  fi

  local -i tm
  while read -r line; do
    tm=$(ts "$line")
    [ $tm -gt $end ] && break
    [ $tm -lt $start ] && continue
    echo "$line"
  done < <(sudo cat "$file")
}

declare -i start=$(ts "${1:?}")
declare -i end=$(ts "${2:-$(date)}")

declare file="${3:?}"
[ -e "$file" ] || exit 1

showlines
