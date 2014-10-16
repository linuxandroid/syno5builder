#!/bin/sh
# Copyright (c) 2000-2014 Synology Inc. All rights reserved.

. /etc.defaults/rc.subr

SASRemoveSDNode()
{
	# remove useless sd* in sas model for fail safe
	# because in SAS model, all device nodes are generated dynamically,
	# so remove these useless device nodes to prevent mis-use
	SDLIST=`ls /dev/* | grep sd[a-z]`
	SDLIST="${SDLIST} `ls /dev/* | grep hd[a-z]`"
	SDLIST="${SDLIST} `ls /dev/* | grep sas[1-9]`"
	SDLIST="${SDLIST} `ls /dev/* | grep usb[1-9]`"
	SDLIST="${SDLIST} `ls /dev/* | grep iscsi[1-9]`"
	SDLIST="${SDLIST} `ls /dev/erase*`"
	if [ -n "${SDLIST}" ]; then
		rm ${SDLIST}
	fi
	SYNOGenAllDeviceNodes
}

SASAssignEncID()
{
	/usr/syno/sbin/enclosureidassign
}

SubTunDiskPerformance()
{
	DISKLIST=`/usr/syno/bin/synodiskport -$1`
	for disk in ${DISKLIST};
	do
		/usr/syno/bin/sasdisktune ${disk}
	done
}

SASTunDiskPerformance()
{
	echo "tunning SAS disk performance"
	SubTunDiskPerformance internal
	SubTunDiskPerformance eunit
	# We don't tune SSD cache scheduler to CFQ here
	# unless there are SSDs which work in SAS protocol and their performance suffer by using Anticipatory as scheduler
}

# interrupt SAS disk self test, for #47006
SubInterruptDiskSelfTest()
{
	DISKLIST=`/usr/syno/bin/synodiskport -$1`
	for disk in ${DISKLIST};
	do
		/usr/syno/bin/sasdiskselftestinterrupt ${disk}
	done
}

SASInterruptDiskSelfTest()
{
	echo "interrupt SAS disk self test"
	SubInterruptDiskSelfTest internal
	SubInterruptDiskSelfTest eunit
}

