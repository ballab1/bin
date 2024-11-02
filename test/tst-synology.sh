#!/bin/bash


START="$(date '+%s')"
declare -i MAX_ITER=100
declare RESULTS_LOG='results.log'
declare -a VARIABLES=( 'K8S K8S'
                       'K8S volume1'
                       'K8S /volume1'
                       'K8S /volume1/K8S'
                       '/K8S /K8S'
                       '/K8S volume1'
                       '/K8S /volume1'
                       '/K8S /volume1/K8S'
                       'volume1 K8S'
                       'volume1 /K8S'
                       'volume1 /volume1/K8S'
                       '/volume1 K8S'
                       '/volume1 /K8S'
                       '/volume1 /volume1/K8S'
                       '/volume1/K8S volume1'
                       '/volume1/K8S /volume1'
                       '/volume1/K8S K8S'
                       '/volume1/K8S /K8S'
                       '/volume1/K8S /volume1/K8S'
)

# ---------------------------------------------------------------------------
function fmtElapsedTime()
{
    local -ir elapsed=${1:?"Input parameter 'elapsed' must be passed to 'function ${FUNCNAME[0]}()'"}

    printf '%02d:%02d:%02d' $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60))
}

# ---------------------------------------------------------------------------
function main() {
  local -i ID=0
  local -i begin last
  begin="$START"
  [ -f "$RESULTS_LOG" ] && rm "$RESULTS_LOG"
  for params in "${VARIABLES[@]}"; do
    #shellcheck disable=SC2086
    result="$(test $params)"
    last="$(date '+%s')"
    printf '%s: id: %s, %s\n' "$(fmtElapsedTime "$((last-begin))")" "$(( ID++ ))" "$result"
    begin="$last"
  done > "$RESULTS_LOG"
}

# ---------------------------------------------------------------------------
function node_start() {

  local -r pod="${1:?}"

  LAST="$(kubectl logs -n synology -c csi-plugin --tail 1 "${pod}" | cut -d ' ' -f 1)"
  if [ "${#LAST}" -gt 0 ];then
     local -i SECS="$(date '+%s' --date="$LAST")"
     date "--date=@$(( SECS + 1 ))" '+%Y-%m-%dT%T%:z'
  fi
}

# ---------------------------------------------------------------------------
function node_time() {

  local -r pod="${1:?}"
  local -r start="${2:?}"

  # wait until we have sufficient lines logged
  local LINES=''
  local -i COUNT=0
  while true; do
    LINES="$(kubectl logs -n synology -c csi-plugin --since-time="${start}" "$POD" | grep ' \[ERROR\] ')"
    if [ "${#LINES}" -gt 20 ] && [ "$(wc -l <<< "$LINES")" -gt 0 ]; then
      # return time of last error found
      echo "$COUNT"
      tail -1 <<< "$LINES" | cut -d ' ' -f 1
      return
    fi
    [ "$(( ++COUNT ))" -ge "$MAX_ITER" ] && break
    sleep 2
  done
  echo "$COUNT"
  echo '---------------'
}

# ---------------------------------------------------------------------------
function onExit() {
  trap - EXIT
  if [ -f "$RESULTS_LOG" ]; then
    echo
    cat "$RESULTS_LOG"
  fi
  local -i last=""
  local -i elapsed="$(( $(date '+%s') - START ))"
  [ "$elapsed" -gt 2 ] && printf '\nElapsed time: %s\n' "$(fmtElapsedTime "$elapsed")"
}

# ---------------------------------------------------------------------------
function run_test() {
  # get the node used by configured parameters
  local NODE=''
  local -i COUNT=0
  while [ "${#NODE}" -eq 0 ];do
    NODE="$(kubectl get pod -n postgres -o 'jsonpath={.items[0].spec.nodeName}' 2>/dev/null)"
    [ "${#NODE}" -gt 0 ] && break
    [ "$(( ++COUNT ))" -ge "$MAX_ITER" ] && break
    sleep 2
  done
  if [ "${#NODE}" -eq 0 ]; then
      printf 'id: %s, source: %s, volumeHandle: %s, result: postgres node not found\n' "$id" "$source" "$volume"
  else
    # get the associated start time (now we know the node)
    local -r POD="${POD_MAP[$NODE]}"
    if [ "${#POD}" -gt 0 ]; then
      # print the test parameters being tested and result
      printf 'source: %s, volumeHandle: %s, count: %s, result: %s' "$source" "$volume" $(node_time "$POD" "${POD_TIMES[$NODE]}")
    fi
  fi
}

# ---------------------------------------------------------------------------
function test() {

 local source="${1:?}"
 local volume="${2:?}"

  # update config in 'postgresql/40.PersistentVolume.yml'
  sed -i -E \
      -e 's|^(\s+source: ).*$|\1'"$source"'|' \
      -e 's|^(\s+volumeHandle: ).*$|\1'"$volume"'|' \
      'postgresql/40.PersistentVolume.yml'

  # get the pod id's running on each node (use node as index)
  local -r JQ_RSLT="$(kubectl get pod -n synology -o json | jq -r '.items[]|select(.metadata.labels.app == "node")|"[\(.spec.nodeName)]=\(.metadata.name)"' )"
  local -A POD_MAP
  eval "POD_MAP=( $JQ_RSLT )"

  # get the time on the last log from each pod of each node (use node as index, also time is prior to starting test)
  local -A POD_TIMES=()
  for node in "${!POD_MAP[@]}"; do
    POD_TIMES["$node"]="$(node_start "${POD_MAP[$node]}")"
  done

  # configure PV & PVC to use our test parameters
  kubectl create -f postgresql > /dev/null
  yaml2json postgresql/40.PersistentVolume.yml | jq -c '.spec.csi|{id:'"${ID}"', source: ."volumeAttributes".source, "volumeHandle"}' >&2
  run_test
  kubectl delete -f postgresql > /dev/null
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

trap onExit EXIT
main
