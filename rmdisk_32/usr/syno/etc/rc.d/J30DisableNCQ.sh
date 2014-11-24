#/bin/sh

DISK_PATH=/sys/block/sd*/device/
NCQ_OFF_LIST=/usr/syno/etc/ncq_off_list
NCQOFF_DISK=`cat $NCQ_OFF_LIST`
NCQ_RET=1

for i in $DISK_PATH
do
	Disk=`cat $i/model`
	for j in $NCQOFF_DISK
	do
		echo $Disk |grep $j >/dev/null 2>&1
		ret=$?
		if [ 0 -eq $ret ]; then
			NCQ_Value=`cat $i/queue_depth`
			if [ ! 1 -eq $NCQ_Value ]; then
				NCQ_RET=0
				echo Disable $j NCQ
				echo 1 > $i/queue_depth
			fi
		fi
	done
done
exit $NCQ_RET
