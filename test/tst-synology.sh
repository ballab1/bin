#!/bin/bash


START="$(date '+%s')"

declare -r NAMESPACE='synology'
declare -r CHART_NAME='synology-csi/synology-csi'
declare -r RELEASE_VERIONS='0.10.1'
declare -r RELEASE_NAME='synology-csi'
declare -r HELM_VALUES='synology-helm-values.yml'
declare -r TEST_DEFN_DIR='postgresql'
declare -r PV_DEFINITION="$TEST_DEFN_DIR/40.PersistentVolume.yml"
declare -r TEST_DEFN_NS='postgres'
declare -r CONSOLE_OUT='console.log'
declare -r RESULTS_FILE='results.log'
declare -r ERRORS_FILE='errors.log'
declare -i MAX_ITER=100

declare -a LOCATIONS=( 'K8S'
                       '/K8S'
                       'volume1'
                       '/volume1'
                       'volume1/K8S'
                       '/volume1/K8S'
                       '10.3.1.4'
                       '//10.3.1.4'
                       '//10.3.1.4/K8S'
                       '//10.3.1.4/volume1'
                       '//10.3.1.4/volume1/K8S'
                     )

declare -a VARIABLES=( 'K8S K8S'
                       'K8S /K8S'
                       'K8S volume1'
                       'K8S /volume1'
                       'K8S /volume1/K8S'
                       'K8S 10.3.1.4/K8S'
                       'K8S //10.3.1.4/K8S'
                       'K8S //10.3.1.4/volume1/K8S'
                       '/K8S K8S'
                       '/K8S /K8S'
                       '/K8S volume1'
                       '/K8S /volume1'
                       '/K8S /volume1/K8S'
                       '/K8S 10.3.1.4/K8S'
                       '/K8S //10.3.1.4/K8S'
                       '/K8S //10.3.1.4/volume1/K8S'
                       'volume1 K8S'
                       'volume1 /K8S'
                       'volume1 /volume1/K8S'
                       'volume1 10.3.1.4/K8S'
                       'volume1 //10.3.1.4/K8S'
                       'volume1 //10.3.1.4/volume1/K8S'
                       '/volume1 K8S'
                       '/volume1 /K8S'
                       '/volume1 /volume1/K8S'
                       '/volume1 10.3.1.4/K8S'
                       '/volume1 //10.3.1.4/K8S'
                       '/volume1 //10.3.1.4/volume1/K8S'
                       '/volume1/K8S K8S'
                       '/volume1/K8S /K8S'
                       '/volume1/K8S volume1'
                       '/volume1/K8S /volume1'
                       '/volume1/K8S /volume1/K8S'
                       '/volume1/K8S 10.3.1.4/K8S'
                       '/volume1/K8S //10.3.1.4/K8S'
                       '/volume1/K8S 10.3.1.4/volume1'
                       '/volume1/K8S //10.3.1.4/volume1'
                       '/volume1/K8S 10.3.1.4/volume1/K8S'
                       '/volume1/K8S //10.3.1.4/volume1/K8S'
                       '10.3.1.4 K8S'
                       '10.3.1.4 /K8S'
                       '10.3.1.4 volume1'
                       '10.3.1.4 /volume1'
                       '10.3.1.4 /volume1/K8S'
                       '10.3.1.4 10.3.1.4/K8S'
                       '10.3.1.4 //10.3.1.4/K8S'
                       '10.3.1.4 10.3.1.4/volume1'
                       '10.3.1.4 //10.3.1.4/volume1'
                       '10.3.1.4 10.3.1.4/volume1/K8S'
                       '10.3.1.4 //10.3.1.4/volume1/K8S'
                       '//10.3.1.4 K8S'
                       '//10.3.1.4 /K8S'
                       '//10.3.1.4 volume1'
                       '//10.3.1.4 /volume1'
                       '//10.3.1.4 /volume1/K8S'
                       '//10.3.1.4 10.3.1.4/K8S'
                       '//10.3.1.4 //10.3.1.4/K8S'
                       '//10.3.1.4 10.3.1.4/volume1'
                       '//10.3.1.4 //10.3.1.4/volume1'
                       '//10.3.1.4 10.3.1.4/volume1/K8S'
                       '//10.3.1.4 //10.3.1.4/volume1/K8S'
                       '10.3.1.4/K8S K8S'
                       '10.3.1.4/K8S /K8S'
                       '10.3.1.4/K8S volume1'
                       '10.3.1.4/K8S /volume1'
                       '10.3.1.4/K8S /volume1/K8S'
                       '10.3.1.4/K8S 10.3.1.4/K8S'
                       '10.3.1.4/K8S //10.3.1.4/K8S'
                       '10.3.1.4/K8S 10.3.1.4/volume1'
                       '10.3.1.4/K8S //10.3.1.4/volume1'
                       '10.3.1.4/K8S 10.3.1.4/volume1/K8S'
                       '10.3.1.4/K8S //10.3.1.4/volume1/K8S'
                       '10.3.1.4/volume1 K8S'
                       '10.3.1.4/volume1 /K8S'
                       '10.3.1.4/volume1 volume1'
                       '10.3.1.4/volume1 /volume1'
                       '10.3.1.4/volume1 /volume1/K8S'
                       '10.3.1.4/volume1 10.3.1.4/K8S'
                       '10.3.1.4/volume1 //10.3.1.4/K8S'
                       '10.3.1.4/volume1 10.3.1.4/volume1'
                       '10.3.1.4/volume1 //10.3.1.4/volume1'
                       '10.3.1.4/volume1 10.3.1.4/volume1/K8S'
                       '10.3.1.4/volume1 //10.3.1.4/volume1/K8S'
                       '10.3.1.4/volume1/K8S K8S'
                       '10.3.1.4/volume1/K8S /K8S'
                       '10.3.1.4/volume1/K8S volume1'
                       '10.3.1.4/volume1/K8S /volume1'
                       '10.3.1.4/volume1/K8S /volume1/K8S'
                       '10.3.1.4/volume1/K8S 10.3.1.4/K8S'
                       '10.3.1.4/volume1/K8S //10.3.1.4/K8S'
                       '10.3.1.4/volume1/K8S 10.3.1.4/volume1'
                       '10.3.1.4/volume1/K8S //10.3.1.4/volume1'
                       '10.3.1.4/volume1/K8S 10.3.1.4/volume1/K8S'
                       '10.3.1.4/volume1/K8S //10.3.1.4/volume1/K8S'
                       '//10.3.1.4/K8S K8S'
                       '//10.3.1.4/K8S /K8S'
                       '//10.3.1.4/K8S volume1'
                       '//10.3.1.4/K8S /volume1'
                       '//10.3.1.4/K8S /volume1/K8S'
                       '//10.3.1.4/K8S 10.3.1.4/K8S'
                       '//10.3.1.4/K8S //10.3.1.4/K8S'
                       '//10.3.1.4/K8S 10.3.1.4/volume1'
                       '//10.3.1.4/K8S //10.3.1.4/volume1'
                       '//10.3.1.4/K8S 10.3.1.4/volume1/K8S'
                       '//10.3.1.4/K8S //10.3.1.4/volume1/K8S'
                       '//10.3.1.4/volume1 K8S'
                       '//10.3.1.4/volume1 /K8S'
                       '//10.3.1.4/volume1 volume1'
                       '//10.3.1.4/volume1 /volume1'
                       '//10.3.1.4/volume1 /volume1/K8S'
                       '//10.3.1.4/volume1 10.3.1.4/K8S'
                       '//10.3.1.4/volume1 //10.3.1.4/K8S'
                       '//10.3.1.4/volume1 10.3.1.4/volume1'
                       '//10.3.1.4/volume1 //10.3.1.4/volume1'
                       '//10.3.1.4/volume1 10.3.1.4/volume1/K8S'
                       '//10.3.1.4/volume1 //10.3.1.4/volume1/K8S'
                       '//10.3.1.4/volume1/K8S K8S'
                       '//10.3.1.4/volume1/K8S /K8S'
                       '//10.3.1.4/volume1/K8S volume1'
                       '//10.3.1.4/volume1/K8S /volume1'
                       '//10.3.1.4/volume1/K8S /volume1/K8S'
                       '//10.3.1.4/volume1/K8S 10.3.1.4/K8S'
                       '//10.3.1.4/volume1/K8S //10.3.1.4/K8S'
                       '//10.3.1.4/volume1/K8S 10.3.1.4/volume1'
                       '//10.3.1.4/volume1/K8S //10.3.1.4/volume1'
                       '//10.3.1.4/volume1/K8S 10.3.1.4/volume1/K8S'
                       '//10.3.1.4/volume1/K8S //10.3.1.4/volume1/K8S'
)

# ---------------------------------------------------------------------------
function fmtElapsedTime()
{
    local -ir elapsed=${1:?"Input parameter 'elapsed' must be passed to 'function ${FUNCNAME[0]}()'"}

    printf '%02d:%02d:%02d' $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60))
}

# ---------------------------------------------------------------------------
function main() {
  local location
  local -i ID=0

  begin="$START"
  cd ~/workspace || :
  [ -f "$ERRORS_FILE" ] && :> "$ERRORS_FILE"
  [ -f "$RESULTS_FILE" ] && rm "$RESULTS_FILE"
  [ "$(kubectl get namespace -o json | jq -r '[.items[]|select(.metadata.name == "'"$NAMESPACE"'")]|length')" -eq 0 ] && kubectl create namespace "$NAMESPACE" > /dev/null

  for location in "${LOCATIONS[@]}"; do
    test_variables "$location"
  done
}

# ---------------------------------------------------------------------------
function node_start() {

  local -r pod="${1:?}"

  LAST="$(kubectl logs -n "$NAMESPACE" -c csi-plugin --tail 1 "${pod}" | cut -d ' ' -f 1)"
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
    LINES="$(kubectl logs -n "$NAMESPACE" -c csi-plugin --since-time="${start}" "$POD" | grep ' \[ERROR\] ')"
    if [ "${#LINES}" -gt 20 ] && [ "$(wc -l <<< "$LINES")" -gt 0 ]; then
      # return time of last error found
      echo "$COUNT"
      LINES="$(tail -1 <<< "$LINES")"
      echo "$LINES" | cut -d ' ' -f 1
      printf '%s: %s\n' "$ID" "$LINES" >> "$ERRORS_FILE"
      return
    fi
    [ "$(( ++COUNT ))" -ge "$MAX_ITER" ] && break
    sleep 2
  done
  printf '%s:\n' "$ID" >> "$ERRORS_FILE"
  echo "$COUNT"
  echo '---------------'
}

# ---------------------------------------------------------------------------
function onExit() {
  trap - EXIT
  if [ -f "$RESULTS_FILE" ]; then
    echo
    cat "$RESULTS_FILE"
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
    NODE="$(kubectl get pod -n "$TEST_DEFN_NS" -o 'jsonpath={.items[0].spec.nodeName}' 2>/dev/null)"
    [ "${#NODE}" -gt 0 ] && break
    [ "$(( ++COUNT ))" -ge "$MAX_ITER" ] && break
    sleep 2
  done
  if [ "${#NODE}" -eq 0 ]; then
      printf 'id: %s, source: %s, volumeHandle: %s, result: %s node not found\n' "$ID" "$source" "$volume" "$TEST_DEFN_NS"
  else
    # get the associated start time (now we know the node)
    local -r POD="${POD_MAP[$NODE]}"
    if [ "${#POD}" -gt 0 ]; then
      # print the test parameters being tested and result
      #shellcheck disable=SC2183,SC2046
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
      "$PV_DEFINITION"

  # get the pod id's running on each node (use node as index)
  local -r JQ_RSLT="$(kubectl get pod -n "$NAMESPACE" -o json | jq -r '.items[]|select(.metadata.labels.app == "node")|"[\(.spec.nodeName)]=\(.metadata.name)"' )"
  local -A POD_MAP
  eval "POD_MAP=( $JQ_RSLT )"

  # get the time on the last log from each pod of each node (use node as index, also time is prior to starting test)
  local -A POD_TIMES=()
  for node in "${!POD_MAP[@]}"; do
    POD_TIMES["$node"]="$(node_start "${POD_MAP[$node]}")"
  done

  # configure PV & PVC to use our test parameters
  wait_for_namespace_delete
  kubectl create -f "$TEST_DEFN_DIR" > /dev/null
  yaml2json "$PV_DEFINITION" | jq -c '.spec.csi|{id:'"${ID}"', source: ."volumeAttributes".source, "volumeHandle"}' >&2
  run_test
  kubectl delete -f "$TEST_DEFN_DIR" > /dev/null
}

# ---------------------------------------------------------------------------
function test_variables() {
  local -r location="${1:?}"
  local -i begin last
  local params


  [ "$(helm list -n "$NAMESPACE" -o json | jq 'length')" -gt 0 ] && helm uninstall -n "$NAMESPACE" "$RELEASE_NAME"
  # update helm values
  sed -i -E \
      -e 's|^(\s+location: ).*$|\1'"$location"'|g' \
      "$HELM_VALUES"
  helm install -n "$NAMESPACE" -f "$HELM_VALUES" --version "$RELEASE_VERIONS" "$RELEASE_NAME" "$CHART_NAME" | head -5

  for params in "${VARIABLES[@]}"; do
    #shellcheck disable=SC2086
    result="$(test $params)"
    last="$(date '+%s')"
    printf '%s: id: %s, location: %s, %s\n' "$(fmtElapsedTime "$((last-begin))")" "$(( ID++ ))" "$location" "$result"
    begin="$last"
  done >> "$RESULTS_FILE"
}

# ---------------------------------------------------------------------------
function  wait_for_namespace_delete() {

  local json
  while true ;do
    json="$(kubectl get namespace -o json | jq -r '[.items[]|select(.metadata.name == "'"$TEST_DEFN_NS"'")]')"
    [ "$(jq 'length' <<< "$json")" -eq 0 ] && break
    if [ "$(jq -r '.[0].status.phase' <<< "$json")" = 'Active' ]; then
      kubectl delete -f "$TEST_DEFN_DIR" > /dev/null
    fi
    sleep 2
  done
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

trap onExit EXIT
main | tee "$CONSOLE_OUT"
