#!/bin/sh

PATH="$PATH:/bin/"               # cat
PATH="$PAHT:/usr/bin"            # basename
HTTPD="/usr/sbin/httpd"

usage() {
	cat <<EOF
Usage: $(basename $0) [start|stop|restart]
EOF
}

start() {
	if [ -f /usr/syno/web_rd/httpd_rd.conf ]; then
		/bin/echo "Starting httpd:80 in flash_rd..."
		${HTTPD} -p 80 -c /usr/syno/web_rd/httpd_rd.conf
	else
		/bin/echo "Fail to start httpd:80 in flash_rd, httpd.conf not found..."
	fi

	if [ -f /usr/syno/web/httpd.conf ]; then
		/bin/echo "Starting httpd:5000 in flash_rd..."
		${HTTPD} -p 5000 -c /usr/syno/web/httpd.conf
	else
		/bin/echo "Fail to start httpd:5000 in flash_rd, httpd.conf not found..."
	fi
}
stop() {
	/bin/echo "Stoping all httpd..."
	killall $(basename $HTTPD)
	true
}

case "$1" in
	start)   start ;;
	stop)    stop ;;
	restart) stop && start ;;
	*)       usage >&2 ; exit 1 ;;
esac

