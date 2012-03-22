#!/bin/bash

DEBUG=1

TRUE=0
FALSE=1

GTM_IP=$1

SNMP_VERSION="2c"
SNMP_COMMUNITY="public"

OID_GTM_VIP="1.3.6.1.4.1.3375"
OID_GTM_VIP_NAME=${OID_GTM_VIP}".2.3.12.5.2.1.1"
OID_GTM_VIP_POOL_RELATION=${OID_GTM_VIP}".2.3.12.5.2.1.2"
OID_GTM_VIP_POOL_STATUS=${OID_GTM_VIP}".2.3.12.5.2.1.4"

OID_GTM_POOL_NAME=${OID_GTM_VIP}".2.3.6.4.2.1.1"
OID_POOL_NAME=${OID_GTM_VIP}".2.2.5.1.2.1.1"
OID_BEFORE_IP="1.4"
OID_POOL_IP_LIST=${OID_GTM_VIP}".2.3.6.7.2.1.6"

NAGIOS_FILE="/tmp/$GTM_IP.cfg"

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

	echo "GTM_IP : "$GTM_IP

	echo "SNMP_COMMUNITY : "$SNMP_COMMUNITY
	echo "SNMP_VERSION : "$SNMP_VERSION

	echo "OID_GTM_VIP : "$OID_GTM_VIP
fi

##############################################"
#
# Work on VS
#
##############################################"
# Get list of VIPs
snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $GTM_IP $OID_GTM_VIP_NAME | sed -e 's/.*= STRING: "//g' -e 's/"$//g' | sort | uniq | while read line ; do
	echo "========"

	if [ $DEBUG -gt 10 ]; then
		echo "line : "$line
	fi
	# Extract pool name
	vip_name=$(echo $line | sed -e 's/.* STRING: "//g' -e 's/"$//g' )
	echo 'vip_name : '$vip_name

	# Get pool name code from pool name
	vip_name_code=""
	get_vip_name_code $vip_name
	echo "	vip_name_code : "$vip_name_code

	# Get list of IPs in Pool
	vip_pool_relation="$(snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $GTM_IP ${OID_GTM_VIP_POOL_RELATION}"."${vip_name_code}| grep STRING | sed -e 's/.* STRING: "//g' -e 's/"$//g')"
	echo "	vip_pool_relation : "$vip_pool_relation


	# Get pool name code from pool name
	pool_name_code=""
	get_pool_name_code $vip_pool_relation
	echo "	pool_name_code : "$pool_name_code

	vip_pool_status="$(snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $GTM_IP ${OID_GTM_VIP_POOL_STATUS}.${vip_name_code}.${pool_name_code} | sed -e 's/.* INTEGER: //g')"
	echo "	vip_pool_status : "$vip_pool_status

	# Write Nagios configuration
	echo "" >> $NAGIOS_FILE
	echo "define service{" >> $NAGIOS_FILE
	echo "    host_name            $GTM_IP" >> $NAGIOS_FILE
	echo "    use                   generic-service" >> $NAGIOS_FILE
	echo "    service_description   VS: $vip_name - Pool: $vip_pool_relation" >> $NAGIOS_FILE
	echo "    check_command         check_snmp!${OID_GTM_VIP_POOL_STATUS}.${vip_name_code}.${pool_name_code} -r $vip_pool_status" >> $NAGIOS_FILE
	echo "}" >> $NAGIOS_FILE
	echo "--> done"
done


##############################################"
#
# Work on Pool
#
##############################################"
# Get list of pools
snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $GTM_IP $OID_GTM_POOL_NAME | sed -e 's/.*= STRING: "//g' -e 's/"$//g' | sort | uniq | while read line ; do
	echo "========"

	if [ $DEBUG -gt 10 ]; then
		echo "line : "$line
	fi
	# Extract pool name
	pool_name=$(echo $line | sed -e 's/.* STRING: "//g' -e 's/"$//g' )
	echo 'pool_name : '$pool_name

	# Get pool name code from pool name
	pool_name_code=""
	get_pool_name_code $pool_name
	echo "	pool_name_code : "$pool_name_code

	# Get list of IPs in Pool
	snmpwalk -On -Oe -c $SNMP_COMMUNITY -v $SNMP_VERSION $GTM_IP ${OID_POOL_IP_LIST}"."${pool_name_code}"."${OID_BEFORE_IP} | while read result ; do
		if [ $DEBUG -gt 10 ]; then
			echo "	ip in pool : "$result
		fi
		vip_status_oid=$(echo "$result" | sed -e 's/ = INTEGER.*//g')
		vip_ip=$(echo "$result" | cut -d' ' -f 1 | awk 'BEGIN { FS = "." } ; { print $(NF-4)"."$(NF-3)"."$(NF-2)"."$(NF-1) }')
		vip_port=$(echo "$result" | cut -d' ' -f 1 | awk 'BEGIN { FS = "." } ; { print $NF }')
		vip_status=$(echo "$result" | sed -e 's/.*INTEGER: //g')

		if [ $DEBUG -gt 0 ]; then
			echo '---------'
			echo "	vip_ip : "$vip_ip
			echo "	vip_port : "$vip_port
			echo "	vip_status : "$vip_status
		fi

		# Write Nagios configuration
		echo "" >> $NAGIOS_FILE
		echo "define service{" >> $NAGIOS_FILE
		echo "    host_name            $GTM_IP" >> $NAGIOS_FILE
		echo "    use                   generic-service" >> $NAGIOS_FILE
		echo "    service_description   Pool: $pool_name - $vip_ip:$vip_port" >> $NAGIOS_FILE
		echo "    check_command         check_snmp!$vip_status_oid -r $vip_status" >> $NAGIOS_FILE
		echo "}" >> $NAGIOS_FILE
		echo "--> done"

	done

done

exit $TRUE
