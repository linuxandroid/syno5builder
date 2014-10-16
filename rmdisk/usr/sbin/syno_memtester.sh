#!/bin/sh

SupportRAID=`/bin/get_key_value /etc/synoinfo.conf supportraid`
if [ "$SupportRAID" = "yes" ]; then
	RootDevice=/dev/md0
else
	RootDevice=/dev/hda1
fi

eval $(grep "^HOSTNAME=" /.memtest)
if [ -n "$HOSTNAME" ]; then
	hostname $HOSTNAME
fi

SZF_MEM_LOG_ROOT="/mntmemtest"
SZF_MEM_PROGRESS="/tmp/memtester.progress"
SZF_MEM_VARLOG=${SZF_MEM_LOG_ROOT}"/var/log/memtester.log"

/bin/mkdir -p ${SZF_MEM_LOG_ROOT}
/bin/mount ${RootDevice} ${SZF_MEM_LOG_ROOT}
/bin/mkdir -p `dirname ${SZF_MEM_VARLOG}`
/bin/echo "0/0" > ${SZF_MEM_VARLOG}
/bin/umount ${SZF_MEM_LOG_ROOT}

/usr/sbin/memtester -max 1 > /dev/null 2>&1
/bin/echo "ERROR=$?" >> ${SZF_MEM_PROGRESS}
/bin/mount ${RootDevice} ${SZF_MEM_LOG_ROOT}
/bin/cp ${SZF_MEM_PROGRESS} ${SZF_MEM_VARLOG}
/bin/umount ${SZF_MEM_LOG_ROOT}


/bin/rmdir ${SZF_MEM_LOG_ROOT}
/sbin/reboot

