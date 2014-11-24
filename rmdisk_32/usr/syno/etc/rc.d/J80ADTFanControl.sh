#!/bin/sh

ADTPWM=pwm2
ADTPWMCONTROL=_syno_control
ADTPWMHIGHFREQ=_high_freq
PECI_ERROR=peci_error
SYNOINFO_DEF=/etc.defaults/synoinfo.conf

findADTPath()
{
	file=/sys/class/hwmon/
	for f in $file*
	do
		if [ -d $f/device ]; then
			name=`cat $f/device/name`
			if [ "$name" == "adt7490" ];then
				ADTDIR=$f/device/
				return 1
			fi
		fi
	done
	return 0
}

supportadt7490=`get_key_value $SYNOINFO_DEF supportadt7490`

if [ "$supportadt7490" = "yes" ]; then
	findADTPath
	if [ 1 -eq $? ]; then
		echo ADT Set FAN SPEED
		#Clean the peci error
		cat $ADTDIR/$PECI_ERROR >/dev/null 2>&1
		#Set high frquency
		echo 1 > $ADTDIR/$ADTPWM$ADTPWMHIGHFREQ
		#Set pwm control to manual
		echo 2 > $ADTDIR/$ADTPWM$ADTPWMCONTROL
		#Set pwm
		echo 125 > $ADTDIR/$ADTPWM
	fi
fi
