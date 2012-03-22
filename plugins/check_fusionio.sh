#!/bin/bash

#!/bin/sh

DEBUG=0

TRUE=0
FALSE=1

NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2

declare -a PARAMETER

if [ $1 ]; then
	DEVICE="$1"
else
	DEVICE="/dev/fct0"
fi

TMP_FILE="/tmp/fusionio_device_"$(echo $DEVICE | sed -e 's/\//_/g')

# media_status="Healthy"

# capacity_reserves_percent="100.00"
CAPACITY_RESERVE_PERCENT_WARNING=20
CAPACITY_RESERVE_PERCENT_CRITICAL=10

# board_degC="40"
BOARD_DEGC_WARNING=60
BOARD_DEGC_CRITICAL=70

# client_status="Attached"

# firmware_version="5.0.6"
# product_name="Fusion-io ioDrive Duo 640GB"
# product_number="7XVKM"
# serial_number="77827"
# board_name="Fusion-io ioDIMM 320GB"

if [ $DEBUG -gt 0 ]; then
	echo "DEVICE: "$DEVICE
fi
/usr/bin/fio-status -d $DEVICE -fk > $TMP_FILE

while read line ; do
	if [ $DEBUG -gt 0 ]; then
		echo "line : "$line
	fi
	if expr index "$line" "=" > /dev/null ; then
		name="$(echo $line | cut -d= -f 1)"
		value="$(echo $line | cut -d= -f 2 | sed -e 's/ /_/g')"
		if [ $DEBUG -gt 0 ]; then
			echo "name: "$name
			echo "value: "$value
		fi

		eval ${name}="${value}"
		if [ $DEBUG -gt 0 ]; then
			echo "parameter: ${!name}"
		fi
	fi
done < $TMP_FILE

#rm -f $TMP_FILE

echo -n "$DEVICE - product_name: "$product_name" - board_name: "$board_name" - firmware_version: "$firmware_version

# Check device health
echo -n " - media_status: "$media_status
if [ "$media_status" != "Healthy" ]; then
	echo -n " ---> media_status is not Healthy !!!"
	exit $NAGIOS_CRITICAL
fi

# Check device attachement
echo -n " - client_status: "$client_status
if [ "$client_status" != "Attached" ]; then
	echo -n " ---> client_status is not Attached !!!"
	exit $NAGIOS_CRITICAL
fi

# Check capacity_reserves_percent
capacity_reserves_percent=$(echo "$capacity_reserves_percent" | sed -e 's/\..*//')
echo -n " - capacity_reserves_percent: "$capacity_reserves_percent"% (w:"$CAPACITY_RESERVE_PERCENT_WARNING"% - c:"$CAPACITY_RESERVE_PERCENT_CRITICAL"%)"
if [ $capacity_reserves_percent -lt $CAPACITY_RESERVE_PERCENT_CRITICAL ]; then
	echo -n "---> capacity_reserves_percent is warning !!!"
	exit $NAGIOS_WARNING
elif [ $capacity_reserves_percent -lt $CAPACITY_RESERVE_PERCENT_WARNING ]; then
	echo -n "---> capacity_reserves_percent is warning !!!"
	exit $NAGIOS_CRITICAL
fi

# Check board temperature
echo -n " - board_degC: "$board_degC" (w:"$BOARD_DEGC_WARNING" - c:"$BOARD_DEGC_CRITICAL")"
if [ $board_degC -gt $BOARD_DEGC_CRITICAL ]  ; then
	echo -n "---> board_degC is critical !!!"
	exit $NAGIOS_CRITICAL
elif [ $board_degC -gt $BOARD_DEGC_WARNING ]; then
	echo "---> board_degC is warning !!!"
	exit $NAGIOS_WARNING
fi

exit $NAGIOS_OK
