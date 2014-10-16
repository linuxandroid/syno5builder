#!/bin/sh

PATH="$PATH:/bin"   #for cat, echo, sleep
PATH="$PATH:/sbin"  #for reboot
do_reboot() {
	sleep 5
	reboot
}

do_reboot &

echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"

cat <<EOF
{
	"success": true,
	"data": {
	}
}
EOF

exit 0
