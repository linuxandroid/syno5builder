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
. /etc/rc.subr

RaidTool="/sbin/raidtool"
Mdadm="/sbin/mdadm"
PROCPARTITION="/proc/partitions"
SupportRAID=`/bin/get_key_value /etc/synoinfo.conf supportraid`
DefaultFS=`/bin/get_key_value /etc/synoinfo.conf defaultfs`
SupportBuildinStorage=`/bin/get_key_value /etc.defaults/synoinfo.conf support_buildin_storage`
if [ "$SupportRAID" = "yes" ]; then
   DISKNODE="/dev/md"
   PARTNO_ROOT="0"
   PARTNO_SWAP="1"
   PARTNO_DATA="2"
else
   DISKNODE="/dev/sda"
   PARTNO_ROOT="1"
   PARTNO_SWAP="2"
   PARTNO_DATA="3"
fi
NONBUILDIN_WRITEABLE_SIZE=4980480
NONBUILDIN_SWAP_SIZE=4194304
BUILDIN_WRITEABLE_SIZE=2097152
BUILDIN_SWAP_SIZE=3145728
ROOT_SKIP=256
SWAP_SKIP=0
LINUX_FS_TYPE=83
LINUX_SWAP_TYPE=82
Sfdisk="/sbin/sfdisk"
Mount="/bin/mount"
Umount="/bin/umount"
FlagFile="/SynoRepart"
FS_RESERIVE="-m 1"
ErrorFile="/tmp/installer.error"
HaveDisk=0

HAS_SYSTEM_PARTITION=0
DO_CLEAN_PARTITION="1"

if [ "yes" == "${SupportBuildinStorage}" ]; then
	WRITEABLE_SIZE=${BUILDIN_WRITEABLE_SIZE}
	SWAP_SIZE=${BUILDIN_SWAP_SIZE}
else
	WRITEABLE_SIZE=${NONBUILDIN_WRITEABLE_SIZE}
	SWAP_SIZE=${NONBUILDIN_SWAP_SIZE}
fi

###########################################################

# stop all burn-in test (memtester or DMA test) before install
/usr/sbin/burnin_test -f &> /dev/null

/bin/echo "Check new disk..."
for i
do
	case "${i}"
	in
		-n)
			DO_CLEAN_PARTITION="0"
			shift
		;;
		-s)
			HAS_SYSTEM_PARTITION=1
			shift
		;;		
	esac
done

/bin/rm ${ErrorFile}

if [ "$SupportRAID" = "yes" ]; then
	diskIdxList=`/usr/syno/bin/synodiskport -internal`
	for DiskIdx in ${diskIdxList} ; do
		/bin/dd if=/dev/${DiskIdx} of=/dev/null count=1 > /dev/null 2>&1
		if [ $? = "0" ]; then
			HaveDisk=1
		fi
	done

	if [ "0" = "${HaveDisk}" ]; then
		IfErrorThenExit "NODISK" 1 ${ErrorFile}
	fi
else
	/bin/dd if=/dev/sda of=/dev/null count=1 > /dev/null 2>&1
	if [ $? != "0" ]; then
		IfErrorThenExit "NODISK" 1 ${ErrorFile}
	fi
fi

/bin/umount /volume1
/sbin/swapoff ${DISKNODE}${PARTNO_SWAP}

if [ "$SupportRAID" = "yes" ]; then
	
	if [ $HAS_SYSTEM_PARTITION -eq 0 ]; then
	    # SupportRAID always do not clean data partition
	    for RaidVol in 1 0; do
		    /bin/echo "${RaidTool} destroy ${RaidVol}"
		    ${Mdadm} -S ${DISKNODE}${RaidVol}
		    ${RaidTool} destroy ${RaidVol}
	    done
	    #${RaidTool} initsys-dd
	    ${RaidTool} initsys
	    IfErrorThenExit "CREATE" $? ${ErrorFile}	
	fi
elif [ "${DO_CLEAN_PARTITION}" = "1" ]; then
	# clean partitions
	for RaidVol in 0 1 2 3 4 5 6 7 8 9 10 11 12 13; do
		/bin/grep md${RaidVol} ${PROCPARTITION}
		if [ $? -eq 0 ]; then
			/bin/echo "${RaidTool} destroy ${RaidVol}"
			${Mdadm} -S ${DISKNODE}${RaidVol}
			${RaidTool} destroy ${RaidVol}
		fi
	done
	
	if [ $HAS_SYSTEM_PARTITION -eq 1 ]; then
	    #Has system partition, just clean data partition
	    for Partition in 3 4; do
		    /bin/echo "Clean partition ${Partition}"
		    CleanPartition ${Partition} ${DISKNODE}
		    IfErrorThenExit "CLEAN" $? ${ErrorFile}
	    done	
	else
	    #Doesn't has system/data partition, clean all partition
	    ${Sfdisk} -M1 ${DISKNODE}
	    ResFdisk=$?
	    IfErrorThenExit "FDISK" $ResFdisk ${ErrorFile}
	    for Partition in 1 2 3 4; do
		    /bin/echo "Clean partition ${Partition}"
		    CleanPartition ${Partition} ${DISKNODE}
		    IfErrorThenExit "CLEAN" $? ${ErrorFile}
	    done
    
	    CreatePartition ${PARTNO_ROOT} ${WRITEABLE_SIZE} ${LINUX_FS_TYPE} ${ROOT_SKIP} ${DISKNODE}
	    IfErrorThenExit "CREATE" $? ${ErrorFile}
	    CreatePartition ${PARTNO_SWAP} ${SWAP_SIZE} ${LINUX_SWAP_TYPE} ${SWAP_SKIP} ${DISKNODE}
	    IfErrorThenExit "CREATE" $? ${ErrorFile}
		sleep 1
	    synodd ${DISKNODE}${PARTNO_ROOT} ${DISKNODE}${PARTNO_SWAP}
	    IfErrorThenExit "SYNODD" $? ${ErrorFile}	    
	fi
else
	#
	# check if the partition match the format
	#
	/usr/syno/bin/synocheckpartition
	RetPartition=$?
	/bin/echo "Partition Version=${RetPartition}"

	if [ ${RetPartition} -eq 1 -o ${RetPartition} -eq 3 ]; then
		/bin/echo "Repartition ${DISKNODE}1 ..."
		CleanPartition ${PARTNO_SWAP} ${DISKNODE}
		# NRAID_V5
		CreatePartition ${PARTNO_ROOT} 722862 ${LINUX_FS_TYPE} ${ROOT_SKIP} ${DISKNODE}
		CreatePartition ${PARTNO_SWAP} 594405 ${LINUX_SWAP_TYPE} ${SWAP_SKIP} ${DISKNODE}
		
		# Clean system partition whatever since partition is re-formated
		HAS_SYSTEM_PARTITION=0		
	fi
fi

if [ $HAS_SYSTEM_PARTITION -eq 0 ]; then
    /bin/echo "mkswap ${DISKNODE}${PARTNO_SWAP}"
    /sbin/mkswap ${DISKNODE}${PARTNO_SWAP}
    IfErrorThenExit "MKSWAP" $? ${ErrorFile}
    /sbin/mkfs.${DefaultFS} ${FS_RESERIVE} -P $* ${DISKNODE}${PARTNO_ROOT} 
    Res=$?
    IfErrorThenExit "MKFS" $Res ${ErrorFile}
/bin/touch "/.1bay_mkfs"
else     
    Res=0
    # Notify Assistant to skip format system partition
    /bin/touch "/.skip_format_sys"
    /bin/echo "touching /.skip_format_sys"
fi

# make a copy of configurations from default
#cp -R	/etc.defaults					/etc
#cp -R	/usr/syno/etc.defaults			/usr/syno/etc
#cp -R	/var.defaults					/var

if [ $Res -eq 0 ]; then
	/bin/mount ${DISKNODE}${PARTNO_ROOT} /mnt
	/bin/touch /mnt/.noroot
	/bin/umount /mnt
fi

if [ -x /usr/syno/bin/mantool ]; then
	/usr/syno/bin/mantool -auto_poweron_disable 1
	/usr/syno/bin/mantool -auto_poweron_disable 2
fi

exit 0

