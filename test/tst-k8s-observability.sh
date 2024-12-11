#!/bin/bash


START="$(date '+%s')"

declare -r RESULTS_FILE='results.log'
declare -r MODULE='observability'
#declare -r ERRORS_FILE='errors.log'


# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
function disable_module() {

  if [ "$(which microk8s)" ]; then

    local python="$(which python)"
    [ "$python" ] || python="$(which python3)"
    local -r json="$("$python" -c 'import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)' < <(microk8s status --format yaml))"

    if [ "$(jq -r '.microk8s.running' <<< "$json")" = 'true' ]; then
      if [ "$(jq -r '.addons[]|select(.name == "'"$MODULE"'").status' <<< "$json")" = 'enabled' ]; then
        microk8s disable "$MODULE" 2>&1
        kubectl delete namespace "$MODULE" 2>&1
      fi
      return 0
    fi
  fi
  echo 'mocrok8s is not running'
  exit 1
}

# ---------------------------------------------------------------------------
function fmtElapsedTime()
{
    local -ir elapsed=${1:?"Input parameter 'elapsed' must be passed to 'function ${FUNCNAME[0]}()'"}

    printf '%02d:%02d:%02d' $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60))
}

# ---------------------------------------------------------------------------
function get_log() {

  local -r node="${1:?}"
  local -r ts="${2:?}"

  local since="$(date --date="@$ts" '+%Y-%m-%d %T')"
  local -a nibbles
  while read -r line; do
    mapfile -t nibbles < <(split_logline "$line")
    nibbles[0]="$(fmtElapsedTime "$(( nibbles[0] - ts ))")"
    printf '%s %s %s\n' "${nibbles[@]}"
  done< <(ssh "$node" 'sudo journalctl --since='"'$since'")
}

# ---------------------------------------------------------------------------
function main() {

  cd ~/workspace || :

  local -a nodes=( 's1.ubuntu.home' 's5.ubuntu.home' 's7.ubuntu.home' )

  disable_module

  local -A NODE_TIMES=()
  for node in "${nodes[@]}"; do
    NODE_TIMES["$node"]="$(node_start "$node")"
    ssh "$node" 'echo "enabling" | systemd-cat -t '"${MODULE^^}"' -p info'
  done

  sudo microk8s enable "$MODULE" ||: 2>&1

  for node in "${nodes[@]}"; do
    echo
    ssh "$node" 'echo "done" | systemd-cat -t '"${MODULE^^}"' -p info'
    get_log "$node" "${NODE_TIMES[$node]}"
  done

  echo
  kubectl get namespaces
  echo
  kubectl get pods -n "$MODULE" -o wide
}

# ---------------------------------------------------------------------------
function node_start() {

  local -r node="${1:?}"

  local -a nibbles
#  mapfile nibbles < <(ssh "$node" 'sudo journalctl -r --lines=1';date '+%s')
#  local ts=${nibbles[1]}"
#  mapfile nibbles < <(split_logline "${nibbles[0]}")
#  ts=$(( nibbles[0] - ts ))"
#  echo "${nibbles[0]}"

  mapfile nibbles < <(split_logline "$(ssh "$node" 'sudo journalctl -r --lines=1')")
  echo "${nibbles[0]}"
}

# ---------------------------------------------------------------------------
function onExit() {
  trap - EXIT
  local -i elapsed="$(( $(date '+%s') - START ))"
  [ "$elapsed" -gt 2 ] && (printf '\nElapsed time: %s\n' "$(fmtElapsedTime "$elapsed")" >&2)
}

# ---------------------------------------------------------------------------
function split_logline() {

  local -r line="${1:?}"

  [ "${#line}" -ge 15 ]  && date '+%s' --date="${line:0:15}"
  [ "${#line}" -ge 30 ]  && echo "${line:16:14}"
  [ "${#line}" -gt 31 ]  && echo "${line:31}"
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

trap onExit EXIT
[ -f "$RESULTS_FILE" ] && rm "$RESULTS_FILE"
main 2>&1 | tee "$RESULTS_FILE"
