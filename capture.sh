#!/bin/bash

kill_tcpdump() {
    PID="$(ps faux|awk '/^tcpdump/ {print $2}')"
    [ -z "${PID:-}" ] || sudo kill "$PID"
}

rm_file() {
    sudo find ~/wireshark -name '*.pcap' -delete
}

start_tcpdump() {
    IFACE="$(ip -4 -j address|jq -r '.[]|select(.qdisc != "noqueue").addr_info[0].label')"
    #IFACE="$(ip -4 -j address|jq -r '.[]|select(.qdisc == "fq_codel").addr_info[0].label')"
    #IFACE="$(ip -4 -j address show scope global dynamic|jq -r '.[0].addr_info[].label')"
    [ -f 'sysfile.log' ] && sudo rm sysfile.log 
    sudo SSLKEYLOGFILE=./keyfile.log tcpdump -i $IFACE -w "$DUMP_FILE" -i "$IFACE" -W 24 -G 3600 --relinquish-privileges=bobb $@ &
}

DUMP_FILE=~/wireshark/capture_%Y-%m-%d_%H-%M-%S.pcap
DC_FILE=~/wireshark/docker-compose.yml
MODE="${1:?'must specify an argument from start|stop|up|down'}"
[ "$#" -gt 0 ] || exit 1
shift

case "$MODE" in
    start)
	kill_tcpdump
	rm_file
	start_tcpdump "$@"
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
    *)
	echo 'invalid argument: [start|stop|up|down]'
	;;
esac
exit 0
