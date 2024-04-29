#!/bin/bash

kill_tcpdump() {
    PID="$(ps faux|awk '/^tcpdump/ {print $2}')"
    [ -z "${PID:-}" ] || sudo kill "$PID"
}

rm_file() {
    [ ! -e  "$DUMP_FILE" ] || sudo rm "$DUMP_FILE"
}

start_tcpdump() {
    IFACE="$(ip -4 -j address show scope global dynamic|jq -r '.[0].addr_info[].label')"
    [ -f 'sysfile.log' ] && sudo rm sysfile.log 
    sudo SSLKEYLOGFILE=./keyfile.log tcpdump -w "$DUMP_FILE" -i "$IFACE" &
}

DUMP_FILE=~/wireshark/tcp.dump
DC_FILE=~/wireshark/docker-compose.yml

case "${1:?'must specify an argument from start|stop|up|down'}" in
    start)
	kill_tcpdump
	rm_file
	start_tcpdump
	;;
    stop)
	kill_tcpdump
        ;;
    up)
	docker-compose -f "$DC_FILE" up -d
	;;
    down)
	docker-compose -f "$DC_FILE" down
        ;;
esac
exit 0
