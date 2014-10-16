#!/bin/sh
# Copyright (c) 2000-2010 Synology Inc. All rights reserved.

# Synology Service which need MDNS
# iTunes(mt-daapd), AFP, TimeMachine, HTTP:5000, Webdav
# Surveillance, PhotoStation, Printer
#
# FIXME: Let each service write down its own mdns service file.
# Should not generate them here

AVAHI_SERVICE_PATH="/usr/syno/avahi/services"
LOGGER="/usr/bin/logger"

log_msg()
{
	$LOGGER -sp $1 -t AVAHI "$2"
}

GetAdminPort() {
	Port=`/bin/get_key_value /etc/synoinfo.conf admin_port`
	if [ "$Port" != "" ]; then
		echo $Port
	else
		echo 5000
	fi
}

AddHTTP() {
	Port=`GetAdminPort`

	# Model name
	Model=`/bin/get_key_value /etc/synoinfo.conf upnpmodelname`

	# Serial number
	SupportMtdSerial=`/bin/get_key_value /etc.defaults/synoinfo.conf support_mtd_serial`
	if [ $SupportMtdSerial = "yes" ]; then
		Serial=`/bin/cat /proc/sys/kernel/syno_serial`
	else
		Serial="No Support mtd Serial"
	fi

	# DSM version
	MajorVersion=`/bin/get_key_value /etc.defaults/VERSION majorversion`
	MinorVersion=`/bin/get_key_value /etc.defaults/VERSION minorversion`
	BuildNumber=`/bin/get_key_value /etc.defaults/VERSION buildnumber`

	# http & https port number
	AdminPort=`/bin/get_key_value /etc/synoinfo.conf admin_port`
	SecureAdminPort=`/bin/get_key_value /etc/synoinfo.conf secure_admin_port`

	# Mac addresses
	maxLanCount=`/bin/get_key_value /etc.defaults/synoinfo.conf maxlanport`
	if [ "$maxLanCount" = "" ]; then
		maxLanCount=1
	fi

	i=0
	while [ $i -lt $maxLanCount ]; do
		set -- `ifconfig | grep "^eth$i"`
		MACaddr=$5
		if [ $i -eq 0 ]; then
			AllMACaddrs="$MACaddr"
		else
			AllMACaddrs="$AllMACaddrs|$MACaddr"
		fi
		i=`expr $i + 1`
	done

	HTTP_SCONF="$AVAHI_SERVICE_PATH/http.service"

	echo -en \
		"<service-group>
<name>$1</name>
<service>
<type>_http._tcp</type>
<port>$Port</port>
<txt-record>vendor=Synology</txt-record>
<txt-record>model=$Model</txt-record>
<txt-record>serial=$Serial</txt-record>
<txt-record>version_major=$MajorVersion</txt-record>
<txt-record>version_minor=$MinorVersion</txt-record>
<txt-record>version_build=$BuildNumber</txt-record>
<txt-record>admin_port=$AdminPort</txt-record>
<txt-record>secure_admin_port=$SecureAdminPort</txt-record>
<txt-record>mac_address=$AllMACaddrs</txt-record>
</service>
</service-group>
" > $HTTP_SCONF
}

CheckServices() {
	ServName=`/bin/get_key_value /etc/sysconfig/network HOSTNAME`

	if ! [ -d $AVAHI_SERVICE_PATH ]; then
		mkdir -p $AVAHI_SERVICE_PATH;
	else
		rm ${AVAHI_SERVICE_PATH}/*.service
	fi

	AddHTTP $ServName
}

DESC="Avahi mDNS/DNS-SD Daemon"
NAME="avahi-daemon"
DAEMON="/usr/syno/sbin/$NAME"

case "$1" in
	start | reload)
		CheckServices
		if ps w | grep "	$NAME" >/dev/null; then
			echo "Reloading $DESC"
			$DAEMON -r
		else
			echo "Starting $DESC"
			$DAEMON -D
		fi
		;;
	stop)
		echo "Stopping $DESC"
		if ! $DAEMON -k; then
			killall -9 $NAME
		fi
		true # ignore kill failure
		;;
	restart)
		$0 stop
		$0 start
		;;
	*)
		echo "usage: $0 {start|stop|restart|reload}"
		;;
esac
