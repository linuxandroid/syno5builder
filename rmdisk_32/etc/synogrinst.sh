#!/bin/sh

# Copyright (c) 2008-2008 Synology Inc. All rights reserved.
# Synology Group Installer script

. /etc/grinst-common.sh

RaidTool="/sbin/raidtool"
Sfdisk="/sbin/sfdisk"
DD="/bin/synodd"
Checksum="/usr/syno/bin/synochecksum"

Rand=`expr $RANDOM % 20`
SupportRAID=`${GetKeyValue} /etc.defaults/synoinfo.conf supportraid`
Version=`${GetKeyValue} /etc.defaults/VERSION buildnumber`
MaxDisks=`${GetKeyValue} /etc.defaults/synoinfo.conf maxdisks`
SupportLCM=`${GetKeyValue} /etc.defaults/synoinfo.conf support_acm`

Script_Installer="/etc/installer.sh"
Script_NewDisk="/etc/newdisk.sh"
FlagRepart="/SynoRepart"
FlagRaid0="/tmp/raid.0"
GRINST_LOCK="/tmp/lock.grinst"

BaseDir="${MntDir}/${Unique}"
ConfFile="${BaseDir}/synogrinst.conf"

LOG "Pid: $$ rand sleep ${Rand}"
sleep ${Rand}

for pid in `ls /tmp/grinst.* | cut -d'.' -f2`; do 
	if [ $$ -gt $pid ]; then 
		LOG "Group Installation has been running..."
		exit 1
	fi
done

if [ -f "${GRINST_LOCK}" ]; then
	LOG "${GRINST_LOCK} exists."
	exit 1
fi
touch "${GRINST_LOCK}"
LedControl "9" 

mkdir -p ${MntDir}
umount -f ${MntDir}
mount ${ControllerIP}:${NFSPath} ${MntDir}
if [ $? != "0" ]; then
	ErrorExit "Cannot mount ${ControllerIP}:${NFSPath} to ${MntDir}"
elif [ ! -d "${BaseDir}" ]; then
	ErrorExit "${BaseDir} not found"
elif [ ! -f "${ConfFile}" ]; then
	ErrorExit "${ConfFile} not found"
fi
SetProgress "Getting ready to install..."

ConfDiskNum=`${GetKeyValue} ${ConfFile} disk_num`
ConfNeedDD=`${GetKeyValue} ${ConfFile} dd_alldisks`
ConfCreateRAID=`${GetKeyValue} ${ConfFile} create_raid`
ConfSpaceDevType=`${GetKeyValue} ${ConfFile} space_dev_type`
ConfSpaceSize=`${GetKeyValue} ${ConfFile} space_size`
ConfConfigured=`${GetKeyValue} ${ConfFile} set_configured`
ConfBurnin=`${GetKeyValue} ${ConfFile} full_burnin`
ConfVersion=`${GetKeyValue} ${ConfFile} version`
if [ -z "${ConfVersion}" ]; then
	ConfVersion="*"
fi
PatchPath="${BaseDir}/${Unique}_${ConfVersion}.pat"
ls ${PatchPath} > /dev/null 2>&1
ReportIfNotEqual $? "0" "${PatchPath} not found"
cd ${BaseDir}
PatchFile=`ls ${Unique}_${ConfVersion}.pat | tail -1`
tar xpf ${PatchFile} -C /tmp VERSION
cd -
PatchVersion=`${GetKeyValue} /tmp/VERSION buildnumber`
PatchUnique=`${GetKeyValue} /tmp/VERSION unique`
ReportIfNotEqual "${PatchUnique}" "${Unique}" "Incompatible patch file"
if [ "${PatchVersion}" -lt "${Version}" ]; then
	ReportIfNotEqual "-1" "0" "Patch Version ${PatchVersion} < Flash Version ${Version}"
fi

DiskNum=0
DiskList=""
idx=0
if [ "${SupportRAID}" = "yes" ]; then
	for DiskIdx in `/usr/syno/bin/synodiskport -internal` ; do
		DiskNum=`expr ${DiskNum} + 1`
		DiskList="${DiskList} /dev/${DiskIdx}"
		idx=`expr $idx + 1`
		if [ $idx -ge ${MaxDisks} ]; then
			break
		fi
	done
	DISKNODE="/dev/md"
	PART_ROOT="0"
	PART_SWAP="1"
	PART_DATA="2"
else
	dd if=/dev/hda of=/dev/null count=1 > /dev/null 2>&1
	if [ $? = "0" ]; then
		DiskNum=1
		DiskList="/dev/hda"
	fi
	DISKNODE=${DiskList}
	PART_ROOT="1"
	PART_SWAP="2"
	PART_DATA="3"
fi
ReportIfNotEqual "${ConfDiskNum}" "${DiskNum}" "${DiskNum} != disk_num(${ConfDiskNum})"

if [ "${SupportRAID}" = "yes" ]; then
	if [ "${ConfCreateRAID}" = "yes" ]; then
		touch ${FlagRepart}
	fi
	UpgradeMnt="/tmpData"
	UpgradePart="${PART_ROOT}"
else
	touch ${FlagRepart}
	UpgradeMnt="/volume1"
	UpgradePart="${PART_DATA}"
fi

if [ ${ConfBurnin} = "yes" ]; then
	touch ${FlagRaid0}
fi

umount ${UpgradeMnt}
swapoff ${DISKNODE}${PART_SWAP}
if [ "${SupportRAID}" = "yes" ]; then
	idx=`expr ${MaxDisks} + 1`
	while [ $idx -ge 0 ]; do
		${RaidTool} destroy $idx
		idx=`expr $idx - 1`
	done
fi

if [ "${ConfNeedDD}" = "yes" ]; then
	SetProgress "DD'ing ${DiskList}"
	${DD} ${DiskList}
	ReportIfNotEqual $? "0" "Failed to DD disks"
	for Disk in ${DiskList} ; do
		${Sfdisk} -M1 ${Disk} > /dev/null 2>&1
	done
fi

SetProgress "Creating System Partition"
${Script_Installer}
if [ -f ${ErrInstall} ]; then
	ReportIfNotEqual "-1" "0" "Failed to create system partition"
fi

#Create data volume: For 1 bay model
if [ "$SupportRAID" != "yes" ]; then
    SetProgress "Creating Data Volume"
    ${Script_NewDisk}
    if [ -f ${ErrInstall} ]; then
	    ReportIfNotEqual "-1" "0" "Failed to create data volume"
    fi
fi

#Patch file
mkdir -p ${UpgradeMnt}
mount ${DISKNODE}${UpgradePart} ${UpgradeMnt}
ReportIfNotEqual $? "0" "Failed to mount upgrade volume"
echo ${UpgradePart} > ${UpgradeMnt}/.upgrade_vol
UpgradeDir="${UpgradeMnt}/upd@te"
UpgradeFile="${UpgradeMnt}/upd@te.pat"

SetProgress "Copy patch file from server after $Rand"
sleep ${Rand}
cp -f "${BaseDir}/${PatchFile}" "${UpgradeFile}"
ReportIfNotEqual $? "0" "Failed to copy patch file"

rm -rf "${UpgradeDir}"
mkdir -p "${UpgradeDir}"
tar xpf "${UpgradeFile}" -C "${UpgradeDir}"
${Checksum} ${UpgradeDir}
if [ $? != "0" ]; then
	SetProgress "Bad patch file"
	rm -rf "${UpgradeDir}"
	rm -rf "${UpgradeFile}"
	umount -f ${MntDir}
	ErrorExit
fi

SetProgress "Updating flash: ${Version} -> ${PatchVersion}"
if [ "${PatchVersion}" -gt "${Version}" ]; then
	${UpgradeDir}/updater -v ${UpgradeMnt}
	Res=$?
	ErrMsg="Failed to update flash"
elif [ "${PatchVersion}" = "${Version}" ]; then
	mv -f "${UpgradeDir}/hda1.tgz" "${UpgradeMnt}/SynoUpgrade.tar.gz"
	Res=$?
	ErrMsg="Failed to update patch"
else
	Res=1
	ErrMsg="Cannot Downgrade: ${PatchVersion} < ${Version}"
fi
rm -rf "${UpgradeDir}"
rm -rf "${UpgradeFile}"
ReportIfNotEqual ${Res} "0" ${ErrMsg}

TmpRoot="/tmpRoot"
mkdir -p ${TmpRoot}
mount ${DISKNODE}${PART_ROOT} ${TmpRoot}
rm -f ${TmpRoot}/.noroot
if [ "${ConfConfigured}" = "yes" ]; then
	touch "${TmpRoot}/.GRINST_OK"
fi

# Setup for full system burn-in
Platform=`echo ${Unique} | cut -d'_' -f2`
if [ ${ConfBurnin} = "yes" ]; then
	cp -f ${MntDir}/fullburnin.sh ${TmpRoot}/.fullburnin.sh
	cp -f ${MntDir}/smb_${Platform}.tar ${TmpRoot}/.smbtool.tar
fi

for conf_sh in ds_configure.sh ds_configure_post_vol.sh
do
	if [ -f ${MntDir}/${conf_sh} ]; then
		cp -f ${MntDir}/${conf_sh} ${TmpRoot}/.${conf_sh}
	fi
	if [ -f ${BaseDir}/${conf_sh} ]; then
		cp -f ${BaseDir}/${conf_sh} ${TmpRoot}/.${conf_sh}
	fi
	chmod 777 ${TmpRoot}/.${conf_sh}
done
touch ${TmpRoot}/.NormalShutdown
touch ${TmpRoot}/.nolog

#Create data volume. For >= 2 bay model
if [ "$SupportRAID" = "yes" -a -e ${FlagRepart} ]; then
	conf_sh="${TmpRoot}/.installer_create_vol.conf"

	if [ "xcustom" != "x${ConfSpaceDevType}" -a "xSHR" != "x${ConfSpaceDevType}" ]; then
	    ConfSpaceDevType="SHR"
	fi
	echo "space_dev_type=${ConfSpaceDevType}" > ${conf_sh}

	if [ -n "${ConfSpaceSize}" ]; then
	    echo "space_size=${ConfSpaceSize}" >> ${conf_sh}
	fi

	SetProgress "Rebooting..."
else
	SetProgress "FINISH and rebooting..."
fi

umount -f ${TmpRoot}

sync; sleep 3
reboot

