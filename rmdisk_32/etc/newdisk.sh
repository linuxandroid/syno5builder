#!/bin/sh

# This script is used to initialize a new disk containing 
# only the first (root) partition from etc/rc. This script
# thus assume root partition is already mounted.
#
# The intended disk layout after executing this script 
# will be:
#	Partition 1: root fs
#	Partition 2: swap
#	Partition 3: user data mounted at /volume1
# 
# It (clear existing if any and re)create partition 2,3,4 
# on /dev/sda.
#
#
. /etc.defaults/rc.subr

PROCPARTITION="/proc/partitions"
SupportRAID=`/bin/get_key_value /etc/synoinfo.conf supportraid`
DefaultFS=`/bin/get_key_value /etc/synoinfo.conf defaultfs`
SupportEBoxExpand=`/bin/get_key_value /etc.defaults/synoinfo.conf support_ebox_expand_vol`
if [ "$SupportRAID" = "yes" ]; then
   DISKNODE="/dev/md"
   PARTNO_SWAP="1"
   PARTNO_DATA="2"
   RaidTool="/sbin/raidtool"
else
   DISKNODE="/dev/sda"
   PARTNO_SWAP="2"
   PARTNO_DATA="3"
fi
DATA_SKIP=262144
DATA_SIZE=-1
LINUX_FS_TYPE=83
LINUX_SWAP_TYPE=82
Sfdisk="/sbin/sfdisk"
Mount="/bin/mount"
Umount="/bin/umount"
FlagFile="/SynoRepart"
FS_RESERIVE=""
ErrorFile="/tmp/installer.error"

# ##########################################################

RCMsg "Checking new disks ..."
if [ ! -e ${FlagFile} ]; then
	echo "No new disk. Do nothing."
	exit 0
else
	echo "New disk. Begin initialization."
fi

rm ${ErrorFile}

# clean data volume
if [ "$SupportRAID" = "yes" ]; then
	for RaidVol in 2; do
		${RaidTool} destroy ${RaidVol}
	done
else
	for Partition in 3 4; do
		# to save some seconds, clear that partition only if it really exists
		grep sda${Partition} ${PROCPARTITION}
		if [ $? -eq 0 ]; then
			echo "Clean partition ${Partition}"
			CleanPartition ${Partition} ${DISKNODE}
			IfErrorThenExit "CLEAN" $? ${ErrorFile}
		fi
	done
fi

# Create data partition 
VOLUME_DEVICE=${DISKNODE}${PARTNO_DATA}
if [ "$SupportRAID" = "yes" ]; then
	${RaidTool} newvol 
else
	# create data partition - use all remaining space
	CreatePartition ${PARTNO_DATA} ${DATA_SIZE} ${LINUX_FS_TYPE} ${DATA_SKIP} ${DISKNODE}
	IfErrorThenExit "CREATE" $? ${ErrorFile}
fi
# swap on to prevent out of memory when making fs of data volume

swapon ${DISKNODE}${PARTNO_SWAP}
mkfs.${DefaultFS} ${FS_RESERIVE} -F -P ${VOLUME_DEVICE}
Res=$?
IfErrorThenExit "MKFS" $Res ${ErrorFile}
swapoff ${DISKNODE}${PARTNO_SWAP}

# make a copy of configurations from default
#cp -R	/etc.defaults					/etc
#cp -R	/usr/syno/etc.defaults			/usr/syno/etc
#cp -R	/var.defaults					/var

if [ $Res -eq 0 ]; then
	rm -rf ${FlagFile}
fi

