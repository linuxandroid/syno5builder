#!/bin/sh

# TODO check if upgrade

# upgrade procedure(draft):
# .check if hda3 is mountable and upgrade file exists
# .backup user's configs
# .delete all files on root partition
# .extract new root fs
# .copy user's configs back to its position
#
# Any needed configuration format updating or new configs
# will be geenerated automatically by config generator.
UpgradeFile="SynoUpgrade.tar.gz"
UpgradeFileDot=".SynoUpgrade.tar.gz"
TarUpgradeFile="SynoUpgrade.tar"
TarUpgradeFileDot=".SynoUpgrade.tar"
SupportRAID=`/bin/get_key_value /etc/synoinfo.conf supportraid`
UbifsVolume=`/bin/get_key_value /etc/synoinfo.conf support_nand_boot`
DefFS=`/bin/get_key_value /etc/synoinfo.conf defaultfs`
DualHead=`/bin/get_key_value /etc/synoinfo.conf support_dual_head`
FsckFlag="/tmp/.fsckfail"
MkfsFlag="/tmp/.mkfsfail"
# executables
Sfdisk="/sbin/sfdisk"
Umount="/bin/umount -f"
Mount="/bin/mount"
Cp="/bin/cp"
Rm="/bin/rm"
Mv="/bin/mv"
Tar="/bin/tar"
Mkdir="/bin/mkdir"
Mkfs="/sbin/mkfs.${DefFS}"
Fsck="/sbin/e2fsck -nq"
# backup configs
BackupDirList="/etc /usr/syno/etc /var /usr/syno/synoman/webman/3rdparty /usr/local /root/.ssh /etc/nginx/sites-enabled"
RemoveUPSFiles="/usr/syno/etc/ups.conf /usr/syno/etc/upsd.conf /usr/syno/etc/upsd.users /usr/syno/etc/upsmon.conf /usr/syno/etc/upssched.conf"
RemovePPPOEFiles="/etc/ppp/ip-up /etc/ppp/ip-down /etc/ppp/ip-function"
RemoveCUPSFilters="/usr/local/cups/filter/bannertops /usr/local/cups/filter/commandtops /usr/local/cups/filter/gziptoany /usr/local/cups/filter/imagetops /usr/local/cups/filter/imagetoraster /usr/local/cups/filter/pdftops /usr/local/cups/filter/pstops /usr/local/cups/filter/rastertoepson /usr/local/cups/filter/rastertohp /usr/local/cups/filter/rastertolabel /usr/local/cups/filter/rastertopwg /usr/local/cups/filter/texttops /usr/local/cups/filter/hpgltops"
RemoveCUPSFiles="/usr/local/cups/mime.types /usr/local/cups/mime.convs /usr/local/cups/cupsd.conf /usr/local/cups/testprint ${RemoveCUPSFilters}"
RemoveHostapdFiles="/etc/hostapd/stainfo.sh /etc/hostapd/mac_filter/mfscript.sh /usr/syno/etc/rfkill.sh"
RemoveSSLFiles="/usr/syno/etc/ssl/mkcert.sh /usr/syno/etc/ssl/mkcgikey.sh"
RemoveUSBModemFiles="/usr/syno/etc/usbmodem/wcdma_list.json /usr/syno/etc/usbmodem/usb_modeswitch.d/*"
RemovePHPFiles="/etc/php/php.ini /etc/php/php-fpm.conf /etc/php/conf.d/opcache.ini"
RemoveSynoServiceConf="/usr/syno/etc/synoservice.d/global.setting /usr/syno/etc/synoservice.d/system.cfg"
RemoveFileList="/etc/ftpusers /etc/rc /etc/rc.network /etc/ssh/sshd_config /usr/syno/etc/rc.atalk /usr/syno/etc/.htpasswd /usr/syno/etc/lpd/lpd.conf /usr/syno/etc/printcap ${RemoveUPSFiles} /etc/lvm/lvm.conf /usr/local/etc/rc.d/SynoEnablePersonalServices.sh /etc/rc.network_routing /usr/syno/etc/rc.tun /usr/syno/etc/afpd.conf /etc/pam.d/samba ${RemovePPPOEFiles} ${RemoveCUPSFiles} ${RemoveHostapdFiles} /usr/syno/etc/iptables_guest_net.sh /etc/ld.so.preload /etc/tc/default.cmd $RemoveSSLFiles /etc/logrotate.conf $RemoveUSBModemFiles $RemovePHPFiles $RemoveSynoServiceConf /usr/syno/etc/ssdp/dsm_desc.xml /usr/syno/etc/iptables_time_ctrl.sh /etc/profile"
RemoveCUPSDir="/usr/local/cups/backend /usr/local/cups/mime"
RemoveDirList="/etc/pam.d /usr/syno/etc/vfs /var/state/ups /usr/syno/etc/ups /var/spool/postfix ${RemoveCUPSDir} /etc/fw_security/sysconf /etc/init /etc/logrotate.d /etc/syslog-ng /var/lib/dpkg /etc/httpd/conf /etc/postgresql /etc/nginx"
LinuxVersion=`/bin/uname -r | /usr/bin/cut -d'.' -f1-2`
LinuxSubVersion=`/bin/uname -r | /usr/bin/cut -d'.' -f3`

if [ "$DualHead" = "yes" ]; then
	DISKNODE="/dev/synoboot"
	DEF_PARTNO="4"
	RootPartition="${DISKNODE}4"
elif [ "$SupportRAID" = "yes" ]; then
	DISKNODE="/dev/md"
	DEF_PARTNO="0"
	RootPartition="${DISKNODE}0"
	SwapPartition="${DISKNODE}1"
else
	DISKNODE="/dev/hda"
	DEF_PARTNO="3"
	RootPartition="${DISKNODE}1"
	SwapPartition="${DISKNODE}2"
fi

RootMnt="/tmpRoot"
UPGRADE_VOL_FILE="${RootMnt}/.upgrade_vol"
NOTIFY_ASSISTANT_INSTALL_VOL_CREATE="${RootMnt}/.assistant_install_create_vol"
IS_INSTALL_CREATE_VOL=0
PLATFORM=`get_key_value /etc.defaults/synoinfo.conf unique | cut -d"_" -f2`

if [ -f ${NOTIFY_ASSISTANT_INSTALL_VOL_CREATE} ]; then
	IS_INSTALL_CREATE_VOL=1
fi

if [ "yes" != "${UbifsVolume}" ]; then
	if [ -f ${UPGRADE_VOL_FILE} ]; then
		DataPartition="${DISKNODE}`cat ${UPGRADE_VOL_FILE}`"
		$Rm -f ${UPGRADE_VOL_FILE}
		echo "found ${UPGRADE_VOL_FILE} and get ${DataPartition}"
	else
		DataPartition="${DISKNODE}${DEF_PARTNO}"
		echo "use default ${DataPartition}"
	fi
fi

if [ "yes" = "${UbifsVolume}" ] || [ ${RootPartition} = ${DataPartition} ]; then
	DataMnt="${RootMnt}"
else
	DataMnt="/tmpData"
fi
BackupDir="${DataMnt}/upd@te"
BackupDir2="${DataMnt}/s@vedconfig"
DotBackupDir="${DataMnt}/.upd@te"
DotBackupDir2="${DataMnt}/.s@vedconfig"

## 
# Clean specified partition
# 
# $1: target
CleanPartition()
{
	$Sfdisk -N$1 -uS -q -f --no-reread -o0 -z0 -t0 -F -D $DISKNODE
	return $?
}

MountRootPartition()
{
	# mount root
	echo "Mount root partition"
	$Mount $RootPartition $RootMnt
	RetMount=$?
	if [ $RetMount -ne 0 ]; then
		# mount root failed
		echo "Mount root partition failed"
		$Umount $DataMnt
		exit 2
	else
		$Rm -f ${FsckFlag}
	fi
}

IsCleanlyUmounted() {
	if [ -z "$1" ]; then
		return 0
	fi
	if [ "${RootPartition}" != "$1" ]; then
		CleanlyUmounted=`${Fsck} $1 | grep "is cleanly umounted"`
		if [ -z "$CleanlyUmounted" ]; then
			return 0
		fi
	elif [ -f "${RootMnt}/.needquotacheck" ]; then
		rm -f ${RootMnt}/.needquotacheck
		echo "Found ${RootPartition}:/.needquotacheck, removed."
	fi
	return 1
}

#
#
# ##########################################################
echo "Begin upgrade procedure"

if [ "yes" != "${UbifsVolume}" ]; then
	IsCleanlyUmounted ${DataPartition}
	IsClean=$?
fi

if [ ${RootMnt} != ${DataMnt} ]; then
	${Mkdir} -p $DataMnt
	# mount data
	echo "Mount data partition"
	echo "$Mount $DataPartition $DataMnt"
	$Mount $DataPartition $DataMnt
	RetMount=$?
	if [ $RetMount -ne 0 ]; then
		# mount data failed
		echo "Mount data partition failed"
		exit 1
	fi
fi

# check flag and upgrade file
if [ -f $DataMnt/$TarUpgradeFile ]; then
	UpgradeFile=$TarUpgradeFile
	UpgradeFileDot=$TarUpgradeFileDot
fi
if [ -f $DataMnt/$UpgradeFile ]; then
	# file exists. start upgrade
	echo "Found an upgrade file on data volume. Begin upgrade"

	if [ -d ${BackupDir2} -o -f ${FsckFlag} ]; then
		if [ -d ${BackupDir2} ]; then
			echo "Found an old version saved upgrade file on data volume."
		else
			echo "${RootDevice} fsck fail or had lost\+found files"
			if [ ${RootMnt} = ${DataMnt} ]; then
				echo "sad.. your patch is just on the failed volume."
				exit 5
			fi
		fi
		
		echo "Try to umount ${RootPartition}"
		${Umount} -f ${RootMnt}

		echo "Begin ${Mkfs} ${RootPartition}"
		${Mkfs} ${RootPartition}

		ResMkfs=$?
		if [ $ResMkfs -ne 0 ]; then
			touch ${MkfsFlag}
			exit 3
		fi

		echo "mounting ${RootPartition}"
		MountRootPartition
	fi

	# rename upgrade patch first
	if [ ${RootMnt} = ${DataMnt} ]; then
		$Mv $DataMnt/$UpgradeFile $DataMnt/$UpgradeFileDot
		UPGRADE_FILE="$DataMnt/$UpgradeFileDot"
		BKPDIR="${DotBackupDir}"
		OLDCONFDIR="${DotBackupDir2}"
	else
		UPGRADE_FILE="$DataMnt/$UpgradeFile"
		BKPDIR="${BackupDir}"
		OLDCONFDIR="${BackupDir2}"
	fi

	# backup user configs before upgrading
	for ConfigDir in ${BackupDirList}; do
		echo "$RootMnt/$ConfigDir ->	${BKPDIR}${ConfigDir}/"
		ConfigPrefix=`dirname ${ConfigDir}`
		mkdir -p ${BKPDIR}/${ConfigPrefix}
		$Mv $RootMnt/$ConfigDir ${BKPDIR}/${ConfigDir}
	done

	# copy upgrade builtin packages
	if [ -d ${DataMnt}/SynoUpgradePackages ]; then
		$Mv ${DataMnt}/SynoUpgradePackages ${RootMnt}/.SynoUpgradePackages
	fi

	# copy upgrade indexdb
	if [ -f ${DataMnt}/SynoUpgradeIndexdb.tgz ]; then
		$Mv ${DataMnt}/SynoUpgradeIndexdb.tgz ${RootMnt}/.SynoUpgradeIndexdb.tgz
	fi

	# copy upgrade synohdpack_img
	if [ -f ${DataMnt}/SynoUpgradeSynohdpackImg.tgz ]; then
		$Mv ${DataMnt}/SynoUpgradeSynohdpackImg.tgz ${RootMnt}/.SynoUpgradeSynohdpackImg.tgz
	fi

	# remove need-to-upgrade files
	for RemovalFile in ${RemoveFileList}; do
		echo "Removing ${BKPDIR}/${RemovalFile}..."
		$Rm -f ${BKPDIR}/${RemovalFile}
	done

	# remove need-to-upgrade dir
	for RemovalDir in ${RemoveDirList}; do
		echo "Removing ${BKPDIR}/${RemovalDir}..."
		$Rm -rf ${BKPDIR}/${RemovalDir}
	done
	
	OLD_PATCH_DIR=$RootMnt/.old_patch_info
	$Rm -rf ${OLD_PATCH_DIR}
	${Mkdir} ${OLD_PATCH_DIR}
	$Cp $RootMnt/etc.defaults/VERSION ${OLD_PATCH_DIR}/VERSION
	$Cp $RootMnt/etc.defaults/synoinfo.conf ${OLD_PATCH_DIR}/synoinfo.conf
	$Cp -rf $RootMnt/.system_info ${OLD_PATCH_DIR}/
	
	# rm all files on root fs
	$Rm -rf $RootMnt/*
	# extract
	if [ "$DualHead" != "yes" ]; then
		mkswap ${SwapPartition}
		swapon ${SwapPartition}
	fi
	echo "Untaring ${UPGRADE_FILE}..."
	$Tar xf $UPGRADE_FILE -C $RootMnt
	# Copy configs to default folders
	$Cp -a $RootMnt/etc				$RootMnt/etc.defaults
	$Cp -a $RootMnt/var				$RootMnt/var.defaults
	$Cp -a $RootMnt/usr/syno/etc	$RootMnt/usr/syno/etc.defaults
	if [ "$DualHead" != "yes" ]; then
		swapoff ${SwapPartition}
	fi
	
	# remove upgrade tarball file
	$Rm -rf $UPGRADE_FILE
	# move database back
	mkdir -p ${RootMnt}/var
	$Mv ${BKPDIR}/var/database ${RootMnt}/var
	# copy backed-up config files
	if [ "yes" = "${UbifsVolume}" ] || [ ${RootPartition} = ${DataPartition} ]; then
		$Cp -alf ${BKPDIR}/* ${RootMnt}/
	else
		$Cp -a ${BKPDIR}/* ${RootMnt}/
	fi
	# remove backup config files
	$Rm -rf ${BKPDIR}

	# modify unique in disk synoinfo.conf for rp and non-rp models
	if [ -x /usr/syno/bin/synohdcfgen ]; then
		insmod /lib/modules/synobios.*
		/bin/mknod /dev/synobios c 201 0
		echo "Starting /usr/syno/bin/synohdcfgen..."
		/usr/syno/bin/synohdcfgen $RootMnt
		RetCfg=$?
		echo "/usr/syno/bin/synohdcfgen returns $RetCfg"
		rmmod `/sbin/lsmod | /bin/grep synobios  | /usr/bin/cut -f 1 -d ' '`
	fi
	# untar indexdb
	if [ -f ${RootMnt}/.SynoUpgradeIndexdb.tgz ]; then
		echo "Untaring .SynoUpgradeIndexdb.tgz";
		$Tar -xf ${RootMnt}/.SynoUpgradeIndexdb.tgz -C ${RootMnt}/usr/syno/synoman/indexdb
		# remove indexdb file
		$Rm -f ${RootMnt}/.SynoUpgradeIndexdb.tgz
	fi
	# untar synohdpack
	if [ -f ${RootMnt}/.SynoUpgradeSynohdpackImg.tgz ]; then
		echo "Untaring .SynoUpgradeSynohdpackImg.tgz";
		$Tar -xf ${RootMnt}/.SynoUpgradeSynohdpackImg.tgz -C ${RootMnt}/usr/syno/synoman/synohdpack
		# remove synohdpack file
		$Rm -f ${RootMnt}/.SynoUpgradeSynohdpackImg.tgz
	fi

	if [ -d ${OLDCONFDIR} ]; then
		echo "Copying old version saved config files"
		$Mv ${OLDCONFDIR}/* ${RootMnt}/
		$Rm -rf ${OLDCONFDIR}
		CleanPartition 4
	fi

	# fix BSD tty node problem. our rootfs has 0,1,2 already
	COUNT=0
	for prefix in p q; do
		for i in 0 1 2 3 4 5 6 7 8 9 a b c d e f; do
			mknod $RootMnt/dev/pty${prefix}${i} c 2 $COUNT 2>/dev/null
			mknod $RootMnt/dev/tty${prefix}${i} c 3 $COUNT 2>/dev/null
			COUNT=`expr $COUNT + 1`
		done
	done


	touch ${RootMnt}/var/.UpgradeBootup
	echo "Touching ${RootPartition}:/var/.UpgradeBootup"
	
	if [ $IS_INSTALL_CREATE_VOL -eq 1 ]; then
	    touch ${NOTIFY_ASSISTANT_INSTALL_VOL_CREATE}
	    echo "Touching ${NOTIFY_ASSISTANT_INSTALL_VOL_CREATE}"
	fi


	# Workaround for BLDK issue in all models that support EUP
	# this file (/var/.updater_enable_rcpower) is read by S79RCPower.sh in the
	# last rebooting to keep RCPower enable during upgrading.
	# And it should be removed now

	if [ -e "$RootMnt/var/.updater_enable_rcpower" ]; then
		rm -f $RootMnt/var/.updater_enable_rcpower
	fi

	sync ; sync ; sync
else
	echo "No upgrade file exists"
fi

if [ "yes" != "${UbifsVolume}" ] && [ $IsClean -ne 1 ]; then
	touch ${DataMnt}/.needquotacheck_upgrade
	echo "Touching ${DataPartition}:/.needquotacheck_upgrade"
fi

# cleanup
sync ; sync ; sync
if [ ${RootMnt} != ${DataMnt} ]; then
	$Umount $DataMnt
fi

echo "End upgrade procedure"
##################################

