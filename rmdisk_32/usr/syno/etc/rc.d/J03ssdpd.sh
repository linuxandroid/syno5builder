#!/bin/sh

PATH="$PATH:/bin/"		# cat, echo
PATH="$PATH:/sbin/"		# ip
PATH="$PATH:/usr/bin"		# basename

SSDPD="/usr/syno/sbin/minissdpd"
DOC_ROOT="/usr/syno/web"

usage() {
	cat <<EOF
Usage: $(basename $0) [start|stop|restart]
EOF
}
warn() {
	local ret=$?
	echo "$@" >&2
	return $ret
}

enum_interface() {
	local i= iface=
	for i in /sys/class/net/*; do
		iface=$(basename $i)
		if [ -d "$i" -a "x$iface" != "xlo" ]; then
			echo $iface;
		fi
	done
}
get_ifinfo() {
	local iface=$1
	# output ip, mac

	if ! ifconfig "$iface" >/dev/null 2>&1; then
		warn "$iface not exist"
		return 1
	fi

	if ! ifconfig "$iface" | grep -q UP; then
		warn "$iface not UP"
		return 1
	fi
	if ! ifconfig "$iface" | grep -q RUNNING; then
		warn "$iface not RUNNING"
		return 1
	fi
	if ! ifconfig "$iface" | grep -q MULTICAST; then
		warn "$iface not MULTICAST"
		return 1
	fi
	if ! ifconfig "$iface" | grep -q BROADCAST; then
		warn "$iface not BROADCAST"
		return 1
	fi

	ip=$(ifconfig "$iface" | grep "inet addr" | cut -d':' -f 2)
	ip=${ip%% *}
	mac=$(cat "/sys/class/net/${iface}/address")
	mac=${mac//:/}

	return 0
}

gen_device_desc() {
	local iface=$1
	local doc_root=${DOC_ROOT}
	local port=5000

	if [ ! -d "$doc_root" ]; then
		warn "can not create ssdp doc root"
		return 1
	fi

	cat >$doc_root/description-$iface.xml <<EOF
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
	<specVersion>
		<major>1</major>
		<minor>0</minor>
	</specVersion>
	<device>
		<deviceType>urn:schemas-upnp-org:device:Basic:1</deviceType>
		<friendlyName>$(hostname) ($upnpmodelname)</friendlyName>
		<manufacturer>Synology</manufacturer>
		<manufacturerURL>http://www.synology.com</manufacturerURL>
		<modelDescription>Synology NAS</modelDescription>
		<modelName>$upnpmodelname</modelName>
		<modelNumber>$upnpmodelname $version</modelNumber>
		<modelURL>http://www.synology.com</modelURL>
		<modelType>NAS</modelType>
		<serialNumber>$mac</serialNumber>
		<UDN>uuid:upnp_SynologyNAS-$mac</UDN>
		<serviceList>
			<service>
				<URLBase>http://$ip:$port</URLBase>
				<serviceType>urn:schemas-dummy-com:service:Dummy:1</serviceType>
				<serviceId>urn:dummy-com:serviceId:dummy1</serviceId>
				<controlURL>/dummy</controlURL>
				<eventSubURL>/dummy</eventSubURL>
				<SCPDURL>/dummy.xml</SCPDURL>
			</service>
		</serviceList>
		<presentationURL>http://$ip:$port/</presentationURL>
	</device>
</root>
EOF
}

start() {
	local reg_service="/usr/syno/bin/reg_ssdp_service"
	local i= cmd=$SSDPD iface="eth0" ip= mac= version= model=

	local majorversion= minorversion= buildphase= buildnumber= builddate= unique= extractsize=440932
	local upnpmodelname=

	. /etc.defaults/VERSION
	eval $(grep upnpmodelname /etc.defaults/synoinfo.conf)

	version=$majorversion.$minorversion-$buildnumber
	model=$unique

	for i in $(enum_interface); do
		cmd="$cmd -i $i"
	done
	echo $cmd
	if ! $cmd; then
		warn "start SSDPD failed"
		return 1
	fi

	for i in $(enum_interface); do
		if ! get_ifinfo $i; then
			continue;
		fi 
		if [ -z "$ip" -o -z "$mac" ]; then
			warn "can not get usable ip address"
			return 1
		fi

		gen_device_desc $i

		$reg_service "$ip" "$mac" "$version" "$model" "$i"
		echo "$reg_service" "$ip" "$mac" "$version" "$model" "$i"
	done
}
stop() {
	killall $(basename $SSDPD)
	true
}

case "$1" in
	start)   start ;;
	stop)    stop ;;
	restart) stop && start ;;
	*)       usage >&2 ; exit 1 ;;
esac

