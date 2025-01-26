#!/bin/bash

##
WORKDIR=~/wireshark
DUMP_FILE_DATE="${WORKDIR}/capture_%Y-%m-%d_%H-%M-%S.pcap"
DUMP_FILE_NUMBER="${WORKDIR}/capture.pcap"
DUMP_FILE="$DUMP_FILE_NUMBER"
DC_FILE="${WORKDIR}/docker-compose.yml"
MAX_FILES=24
FILE_SIZE=700
USER=bobb

#-------------------------------------------------------------------------
function kill_tcpdump() {
    local pid
    local -a pids=( $(ps faux | awk '/_ tcpdump/ && !/awk/ {print $2}') )
    if [ "${#pids[*]}" -gt 0 ]; then
        printf '%s\n' "${pids[*]}"
        for pid in "${pids[@]}"; do
            printf '%s\n' "$pid"
            sudo kill "$pid"
        done
    fi
}

#-------------------------------------------------------------------------
function main() {
    local mode="${1:-}"
    [ "$#" -gt 0 ] && shift
    case "$mode" in
        start)
            kill_tcpdump
            rm_file
            start_tcpdump "$@"
            ;;
        stop)
            kill_tcpdump
            mv_files
            ;;
        up)
            docker-compose -f "$DC_FILE" up -d
            ;;
        down)
            docker-compose -f "$DC_FILE" down
            ;;
        *)
            echo 'Invalid argument. Must specify an argument from : [start|stop|up|down]'
            exit 1
            ;;
    esac
}

#-------------------------------------------------------------------------
function mv_files() {
    [ "$DUMP_FILE" = "$DUMP_FILE_NUMBER" ] || return
    local x
    local -i i=0
    cd "$WORKDIR" ||:
    while [ "$i" -lt "$MAX_FILES" ]; do
        x="$(printf '%02d\n' $i)"
        [ -f "capture.pcap$x" ] || break
        mv "capture.pcap$x" "capture.$x.pcap"
        (( i++ )) ||:
    done
}

#-------------------------------------------------------------------------
function rm_file() {
    sudo find "$WORKDIR" -name 'capture*' -delete
}

#-------------------------------------------------------------------------
function start_tcpdump() {

    #IFACE="$(ip -4 -j address|jq -r '.[]|select(.qdisc == "fq_codel").addr_info[0].label')"
    #IFACE="$(ip -4 -j address show scope global dynamic|jq -r '.[0].addr_info[].label')"
    local iface="$(ip -4 -j address|jq -r '.[]|select(.qdisc != "noqueue").addr_info[0].label')"

    [ -f 'sysfile.log' ] && sudo rm sysfile.log
    # sudo SSLKEYLOGFILE="${WORKDIR}/keyfile.log" tcpdump -i $iface -w "$DUMP_FILE" -W 24 -G 3600 --relinquish-privileges=bobb $@ &
    sudo SSLKEYLOGFILE="${WORKDIR}/keyfile.log" tcpdump -i $iface \
                                                        -w "$DUMP_FILE" \
                                                        -C "$FILE_SIZE" \
                                                        -W "$MAX_FILES" \
                                                        --relinquish-privileges="$USER" "$@" &
}

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------

main "$@"
exit 0
