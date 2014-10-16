#!/bin/sh
remote_test_script='remote_tester.sh'
remote_ip_address='169.254.1.1'
remote_folder='remote_test'
local_mount_point='/mnt'
local_tmp='/root'
led_disable() {
    echo '-7' > /dev/ttyS1
}

msg_log() {
	echo $1 >> /var/log/messages
}

connection_check() {
	# 0 = connected, 1 = disconnected
	local connection_status=1
	local exit_counter=0
	msg_log "remote_command: try to connect to $remote_ip_address"
	while [ "${connection_status}" -eq "1" ]
	do
		sleep 10
		if [ ${exit_counter} -gt "2" ] ; then
			msg_log "remote_command: Network unavailable exit"
			exit 1
		fi

		ping -c1 "${remote_ip_address}" >/dev/null 2>&1
		connection_status=$?

		exit_counter=$(($exit_counter+1))
	done
	msg_log "remote_command: connection established..."
}
mount_remote() {
	mount ${remote_ip_address}:/${remote_folder} ${local_mount_point}

	if [ "0" -ne "$?" ] ; then
		msg_log "remote_command: mount failed!!!"
		exit 1
	else
		msg_log "remote_command: mount successfully"
	fi
}
copy_test_tool() {
	cp ${local_mount_point}/tools/* ${local_tmp}/

	if [ ! -e ${local_tmp}/${remote_test_script} ] ; then
		msg_log "remote_command: script not found"
		umount ${local_mount_point}
		exit 1
	fi

}
main()
{
	connection_check
	mount_remote
	copy_test_tool
	umount ${local_mount_point}
	led_disable
	sh ${local_tmp}/${remote_test_script}
	exit 0
}

main
