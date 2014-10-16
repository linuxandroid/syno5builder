#!/bin/sh

PATH="$PATH:/bin:/sbin:/usr/bin:/usr/sbin"
partition=`/usr/syno/bin/synodiskport -internal`

product=`/bin/get_key_value /etc.defaults/synoinfo.conf product`
SupportBuildinStorage=`/bin/get_key_value /etc.defaults/synoinfo.conf support_buildin_storage`
SupportUSBVolume=`/bin/get_key_value /etc.defaults/synoinfo.conf support_usb_volume`
buildin_storage_node="/dev/sda"
min_buildin_storage_size=7774208

IFACES=`ls /sys/class/net/ | grep eth`
UPIFACE=eth0
for THISIF in ${IFACES}
do
	if [ `cat /sys/class/net/${THISIF}/carrier` -eq 1 ];then
		UPIFACE=${THISIF}
		break;
	fi
done
get_mac() {
    cat /sys/class/net/${UPIFACE}/address
}
get_ip() {
    ifconfig ${UPIFACE} | grep "inet addr" | cut -d: -f2 | cut -d' ' -f1
}
eval $(grep "^upnpmodelname=" /etc.defaults/synoinfo.conf)
eval $(grep "^product=" /etc.defaults/synoinfo.conf)
eval $(grep "^buildnumber=" /etc.defaults/VERSION)
eval $(grep "^majorversion=" /etc.defaults/VERSION)
eval $(grep "^minorversion=" /etc.defaults/VERSION)

disk_size_enough='true'
if [ "xyes" != "x${SupportBuildinStorage}" ]; then
	buildin_storage='false'
	if [ ! -z "$partition" ];then
		has_disk='true'
	else
		has_disk='false'
	fi
else
	buildin_storage='true'
	has_disk='true'
	disk_name=$(basename ${buildin_storage_node})
	disk_size=$(cat /sys/block/${disk_name}/size)
	if [ "0" -eq "${disk_size}" ]; then
		has_disk='false'
	elif [ "${min_buildin_storage_size}" -gt "${disk_size}" ]; then
		disk_size_enough='false'
	fi
fi

if [ "true" == "${has_disk}" ]; then
	/usr/syno/bin/synoupgrade --check-sys > /tmp/webinst.status
fi

cable_ok=false
netlink_ok=false
rss_ok=false

grep "\"success\": false" /tmp/install.progress
if [ $? -eq 1 ]; then
	# /tmp/install.progress existed and key not found
        isInstall='true'
else
	# /tmp/install.progress not existed (no installation occured) or
	# key found (installation failed)
        isInstall='false'
	if [ `cat /sys/class/net/eth0/carrier` -eq 0 ];then
		cable_ok=false
	else
		cable_ok=true
	fi
fi

pingOtherSite() {
	ping -w 1 -W 5 www.google.com >/dev/null
	ping_google=$?
	if [ $ping_google -eq 0 ];then
		netlink_ok=true
		return
	fi

	ping -w 1 -W 5 www.yahoo.com >/dev/null
	ping_yahoo=$?
	if [ $ping_yahoo -eq 0 ];then
		netlink_ok=true
		return
	fi

	ping -w 1 -W 5 www.bing.com >/dev/null
	ping_bing=$?
	if [ $ping_bing -eq 0 ];then
		netlink_ok=true
		return
	fi

	netlink_ok=false
	return
}

if [ "$cable_ok" == "true" ];then 
	list=`grep nameserver /etc/resolv.conf | grep -v "#" | cut -d' ' -f2`
	for each in $list;do
		ping -w 1 -W 5 $each >/dev/null
		ping_nameserver=$?
		if [ $ping_nameserver -eq 0 ];then
			pingOtherSite;
			break;
		fi
	done
fi

/usr/syno/bin/synoupgrade --check >/dev/null 2>&1
if [ $? -eq 0 ];then
	rss_ok=true
fi

SupportWireless=`/bin/get_key_value /etc/synoinfo.conf support_pci_wifi`
SupportBootInst=`/bin/get_key_value /etc.defaults/synoinfo.conf supportbootinst`
SupportSAS=`/bin/get_key_value /etc.defaults/synoinfo.conf supportsas` 
SupportRAID=`/bin/get_key_value /etc.defaults/synoinfo.conf supportraid`

/bin/echo ${HTTP_REFERER} | grep -i "http://10.1.14.1" > /dev/null 2>&1
ip_addr_test=$?
if [ $ip_addr_test -eq 0 ]; then
	isWireless='true'
else
	isWireless='false'
fi

sys_status=`cat /tmp/webinst.status`


cat <<EOF
Expires: Mon, 26 Jul 1990 05:00:00 GMT
Cache-Control: no-store, no-cache, must-revalidate
Pragma: no-cache
Content-type: text/plain; charset="UTF-8"

EOF

cat <<EOF
{
	"success": true,
	"data": {
		"has_disk": ${has_disk},
		"dsinfo": {
			"product": "${product}",
			"model": "${upnpmodelname}",
			"internet_ok": ${rss_ok},
			"ip_addr": "`get_ip`",
			"mac_addr": "`get_mac`",
			"serial": "`cat /proc/sys/kernel/syno_serial`",
			"build_num": ${buildnumber},
			"build_ver": "${majorversion}.${minorversion}-${buildnumber}",
			"is_installing": ${isInstall},
			"clean_all_partition_disks": "`/sbin/raidtool enumformatalldisks`",
			"product": "${product}",
			"buildin_storage": ${buildin_storage},
			"disk_size_enough": ${disk_size_enough},
EOF

if [ "x${SupportWireless}" = "xyes" ]; then
cat <<EOF
			"support_wireless": true,
			"cable_ok": ${cable_ok},
			"netlink_ok": ${netlink_ok},
			"is_wireless": ${isWireless},
EOF
fi

if [ "x${SupportBootInst}" = "xyes" ]; then
cat <<EOF
			"support_boot_install": true,
			"boot_pat_ok": true,
EOF
fi

if [ -f "/tmp/disk_sysinfo" ]; then
cat <<EOF
			"disk_sysinfo": `cat /tmp/disk_sysinfo`,
EOF
fi

if [ "x${SupportRAID}" = "xyes" ] && [ "x${SupportSAS}" != "xyes" ]; then
cat <<EOF
			"show_shr": true,
EOF

fi
cat <<EOF
			"status": "${sys_status}",
			"hostname": "`hostname`"
		}
	}
}
EOF
