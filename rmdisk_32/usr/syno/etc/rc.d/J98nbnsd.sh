#!/bin/sh

PATH="$PAHT:/usr/bin"            # basename
NBNSD="/usr/syno/sbin/nbnsd"

usage() {
	/bin/cat <<EOF
Usage: $(basename $0) [start|stop|restart]
EOF
}

start() {
	/bin/echo "Starting nbnsd..."
	${NBNSD} &
}
stop() {
	/bin/echo "Stopping nbnsd..."
	killall $(basename ${NBNSD})
	true
}

case "$1" in
	start)   start ;;
	stop)    stop ;;
	restart) stop && start ;;
	*)       usage >&2 ; exit 1 ;;
esac

