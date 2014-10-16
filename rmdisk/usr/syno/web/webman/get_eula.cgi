#!/bin/sh

PATH="$PATH:/bin"

IPTABLES="/sbin/iptables"
SYNOLOGY_WEBSITE="www.synology.com"

# insert iptables for website
SYNOLOGYIP=`ping -c1 -w1 ${SYNOLOGY_WEBSITE} | head -n1 | cut -d' ' -f3 | cut -d'(' -f2 | cut -d')' -f1`
${IPTABLES} -t nat -I PREROUTING -s 10.1.14.0/24 -p tcp -d ${SYNOLOGYIP} -j ACCEPT

# get EULA URL
EULA_URL="http://${SYNOLOGYIP}/support/EULA.php"

# print out
echo -ne "Content-type: text/plain; charset=\"UTF-8\"\r\n\r\n"
printf %s ${EULA_URL}
