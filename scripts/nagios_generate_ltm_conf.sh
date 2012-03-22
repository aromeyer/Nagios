#!/bin/bash

DEBUG=1

TRUE=0
FALSE=1

LTM_IP=$1

SNMP_VERSION="2c"
SNMP_COMMUNITY="public"

OID_LTM_VERSION=".1.3.6.1.4.1.3375.2.1.4.2.0"
OID_LTM_VIP="1.3.6.1.4.1.3375"
OID_LTM_VIP_NAME=${OID_LTM_VIP}".2.2.10.13.2.1.1"

OID_LTM_VIP_STATUS=${OID_LTM_VIP}".2.2.10.13.2.1.2"

OID_LTM_VIP_PORT=${OID_LTM_VIP}".2.2.10.1.2.1.6"
OID_LTM_POOL_NAME=${OID_LTM_VIP}".2.3.6.4.2.1.1"
OID_LTM_VIP_AVAILABLE=${OID_GTM_VIP}".2.3.6.4.2.1.20"
OID_LTM_VIP_POOL_RELATION=${OID_LTM_VIP}".2.2.5.2.3.1.1"
OID_BEFORE_IP="1.4"

OID_LTM_PoolActiveMemberCnt=${OID_LTM_VIP}".2.2.5.1.2.1.8"
OID_LTM_PoolMemberCnt=${OID_LTM_VIP}".2.2.5.6.2.1.8"


OID_LTM_POOL_NAME=${OID_LTM_VIP}".2.2.5.1.2.1.1"


TMP_FILE="/tmp/$LTM_IP.tmp"
NAGIOS_FILE="/tmp/$LTM_IP.cfg"

LTM_VERSION="$(snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $LTM_IP $OID_LTM_VERSION | sed -e 's/.*STRING: "//' -e 's/"$//')"
LTM_MAJOR_VERSION=$(echo $LTM_VERSION | cut -d . -f 1 )

function get_vip_name_code {
	local vip_name=$1

	if [ $DEBUG -gt 10 ]; then
		echo "vip_name : "$vip_name
	fi

	pos_start=0;
	string_length=1
	vip_name_code=${#vip_name}
	while [ $pos_start -lt ${#vip_name} ]; do
		if [ $DEBUG -gt 10 ]; then
			echo "pos_start : "$pos_start" - string_length : "$string_length
			echo "char : "${vip_name:$pos_start:$string_length}
		fi
		vip_name_code=$vip_name_code"."$(printf "%d" "'${vip_name:$pos_start:$string_length}")
		let pos_start++;
	done

	if [ $DEBUG -gt 10 ]; then
		echo "vip_name_code : "$vip_name_code
	fi

}

function get_pool_name_code {
	local pool_name=$1

	if [ $DEBUG -gt 10 ]; then
		echo "pool_name : "$pool_name
	fi

	pos_start=0;
	string_length=1
	pool_name_code=${#pool_name}
	while [ $pos_start -lt ${#pool_name} ]; do
		if [ $DEBUG -gt 10 ]; then
			echo "pos_start : "$pos_start" - string_length : "$string_length
			echo "char : "${pool_name:$pos_start:$string_length}
		fi
		pool_name_code=$pool_name_code"."$(printf "%d" "'${pool_name:$pos_start:$string_length}")
		let pos_start++;
	done

	if [ $DEBUG -gt 10 ]; then
		echo "pool_name_code : "$pool_name_code
	fi

}

rm -f $NAGIOS_FILE

if [ $DEBUG -gt 0 ]; then
	echo "DEBUG : "$DEBUG

	echo "LTM_IP : "$GTM_IP
	echo "LTM_VERSION : "$LTM_VERSION

	echo "SNMP_COMMUNITY : "$SNMP_COMMUNITY
	echo "SNMP_VERSION : "$SNMP_VERSION

	echo "OID_LTM_VIP : "$OID_GTM_VIP
	echo "OID_LTM_VIP_AVAILABLE : "$OID_LTM_VIP_AVAILABLE
	echo "OID_LTM_VIP_NAME : "$OID_LTM_VIP_NAME
fi

if [ $LTM_MAJOR_VERSION -eq 9 ]; then
	NAGIOS_LTM_VS_CHECK="check-ltm-vs"
elif [ $LTM_MAJOR_VERSION -eq 10 ]; then
	NAGIOS_LTM_VS_CHECK="check-ltm10-vs"
else
	echo "Unknown LTM version $LTM_VERSION !!!"
	exit $FALSE
fi


##############################################"
#
# Work on VS
#
##############################################"
snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $LTM_IP $OID_LTM_VIP_NAME | sed -e 's/.*= STRING: "//g' -e 's/"$//g' | sort | uniq | while read line ; do
	echo "========"

	if [ $DEBUG -gt 0 ]; then
		echo "line : "$line
	fi
	# Extract vip name
	vip_name="$(echo "$line" | sed -e 's/.* STRING: "//g' -e 's/"$//g')"
	echo 'vip_name : '$vip_name

	# Get pool name code from pool name
	vip_name_code=""
	get_vip_name_code $vip_name
	echo "	vip_name_code : "$vip_name_code

	vip_port="$(snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $LTM_IP $OID_LTM_VIP_PORT | grep $vip_name_code | sed -e 's/.* INTEGER: //g')"
	echo "	vip_port : "$vip_port

	# 	echo "=== vip_name : "$vip_name
	#
	# 	vip_ip=$(echo "$line" | cut -d' ' -f 1 | awk 'BEGIN { FS = "." } ; { print $(NF-4)"."$(NF-3)"."$(NF-2)"."$(NF-1) }')
	# 	vip_port=$(echo "$line" | cut -d' ' -f 1 | awk 'BEGIN { FS = "." } ; { print $NF }')
	# 	echo "vip_ip : "$vip_ip
	# 	echo "vip_port : "$vip_port

	vip_status="$(snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $LTM_IP $OID_LTM_VIP_STATUS.$vip_name_code | sed -e 's/.* INTEGER: //g')"
	echo "	vip_status : "$vip_status

	if [ $vip_status -eq 1 ]; then
		echo "" >> $NAGIOS_FILE
		echo "define service{" >> $NAGIOS_FILE
		echo "       host_name           $LTM_IP" >> $NAGIOS_FILE
		echo "       use generic-service" >> $NAGIOS_FILE
		echo "       service_description $vip_name" >> $NAGIOS_FILE
		echo "       check_command                    $NAGIOS_LTM_VS_CHECK!public!$vip_name!$vip_port" >> $NAGIOS_FILE
		echo "       notifications_enabled 1" >> $NAGIOS_FILE
		echo "}" >> $NAGIOS_FILE
	else
		echo "	--> vip_status is not in enabled state --> skip"
	fi

done

##############################################"
#
# Work on Pool
#
##############################################"
snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $LTM_IP $OID_LTM_POOL_NAME | sed -e 's/.*= STRING: "//g' -e 's/"$//g' | sort | uniq | while read line ; do
	echo "========"

	if [ $DEBUG -gt 0 ]; then
		echo "line : "$line
	fi
	# Extract vip name
	pool_name="$(echo "$line" | sed -e 's/.* STRING: "//g' -e 's/"$//g')"
	echo 'pool_name : '$pool_name

	# Get pool name code from pool name
	pool_name_code=""
	get_pool_name_code $pool_name
	echo "	pool_name_code : "$pool_name_code

	poolactivememebercount="$(snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $LTM_IP $OID_LTM_PoolActiveMemberCnt.$pool_name_code | sed -e 's/.* INTEGER: //g')"
	echo "	poolactivememebercount: "$poolactivememebercount

	if [ $DEBUG -gt 10 ]; then
		# Loop over pool members
		snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $LTM_IP $OID_LTM_PoolMemberCnt | grep $vip_name_code.$OID_BEFORE_IP | sed -e 's/ = .*$//g' | while read poolmember ; do
			echo "	--> poolmember : "$poolmember
			poolmember_ip=$(echo "$poolmember" | cut -d' ' -f 1 | awk 'BEGIN { FS = "." } ; { print $(NF-4)"."$(NF-3)"."$(NF-2)"."$(NF-1) }')
			poolmember_port=$(echo "$poolmember" | cut -d' ' -f 1 | awk 'BEGIN { FS = "." } ; { print $NF }')
			echo "		poolmember_ip : "$poolmember_ip
			echo "		poolmember_port : "$poolmember_port

			vip_port=$poolmember_port
		done
	fi

	if [ $poolactivememebercount -eq 0 ]; then
		echo " --> no active member in pool --> skip"
	else
		echo "" >> $NAGIOS_FILE
		echo "define service{" >> $NAGIOS_FILE
		echo "       host_name          $LTM_IP" >> $NAGIOS_FILE
		echo "       use generic-service" >> $NAGIOS_FILE
		echo "       service_description  Pool $pool_name" >> $NAGIOS_FILE
		if [ $poolactivememebercount -eq 1 ]; then
			echo "       check_command                    check-ltm-pool!public!$pool_name!1!1" >> $NAGIOS_FILE
		else
			echo "       check_command                    check-ltm-pool!public!$pool_name!2!1" >> $NAGIOS_FILE
		fi
		echo "       active_checks_enabled 1" >> $NAGIOS_FILE
		echo "}" >> $NAGIOS_FILE
		echo "--> done"
	fi

done

exit $TRUE