#!/bin/bash

# DEBUG LEVEL
DEBUG=0

# Boolean
TRUE=0
FALSE=1

#########################
#
# SNMP Configuration
#
#########################
# Get system identifier == product class identifier
OID_sysObjectID="SNMPv2-MIB::sysObjectID.0"
Cisco6500="SNMPv2-SMI::enterprises.9.1.282"
Cisco3750="SNMPv2-SMI::enterprises.9.1.516"
# System Description (IOS version...)
OID_sysDescr="SNMPv2-MIB::sysDescr.0"
# Interface Id
#IF-MIB::ifIndex.10131 = 10131
OID_ifIndex="IF-MIB::ifIndex"
# Interface Status
#IF-MIB::ifAdminStatus.10107 = INTEGER: up(1) 
OID_ifAdminStatus="IF-MIB::ifAdminStatus"
#IF-MIB::ifOperStatus.10107 = INTEGER: up(1) 
OID_ifOperStatus="IF-MIB::ifOperStatus"
# Interface Description
#IF-MIB::ifAlias.10140 = STRING: zm76.ilo
OID_ifAlias="IF-MIB::ifAlias"
# IF-MIB::ifDescr.10639 = STRING: GigabitEthernet2/0/39
OID_ifDescr="IF-MIB::ifDescr"
# Fan
FAN_BASE_INDEX="004"
FAN_BASE_INDEX2="061"
# Power
POWER_BASE_INDEX="003"
POWER_BASE_INDEX2="060"
# Temperature
TEMPERATURE_BASE_INDEX="005"
TEMPERATURE_BASE_INDEX2="006"
TEMPERATURE_BASE_INDEX3="062"

MAX_STACK_SIZE=9

# Nagios config file
START="#=== START AUTOMATICALLY GENERATED CONF"
STOP="#=== STOP AUTOMATICALLY GENERATED CONF"

########## FUNCTION #########
function usage {
	echodebug $DEBUG "=== Function usage"

	echo "usage : $(basename $0) [Nagios switch configuration file] {[SNMP community] [SNMP version]}"
	echo "	- Nagios switch configuration file : mandatory - path to the nagios configuration file of the switch"
	echo "	- SNMP community : optionnal - default to public"
	echo "	- SNMP version : optionnal - default to 2c"

	exit $TRUE
}

function parse_input_parameters {
	echodebug $DEBUG "=== Function parse_input_parameters"

	if [ ! $1 ]; then
		echo "Nagios configuration file not found !!!"
		usage
		exit $FALSE
	fi
	NAGIOS_CONF_FILE=$1
	NEW_NAGIOS_CONF_FILE=$NAGIOS_CONF_FILE".new"
	TMP_NAGIOS_CONF_FILE=$NAGIOS_CONF_FILE".tmp"
	rm -f $TMP_NAGIOS_CONF_FILE
	touch $TMP_NAGIOS_CONF_FILE
	SERVICE="generic-service"
	
	if [ ! $2 ]; then
		SNMP_COMMUNITY="public"
	else
		SNMP_COMMUNITY=$2
	fi
	
	if [ ! $3 ]; then
		SNMP_VERSION="2c"
	else
		SNMP_VERSION=$3
	fi

	return $TRUE
}

function nagios_probe_interface_status {
	index=$1
	descr=$2
	operstatus=$3
	alias=$4

	echodebug $DEBUG "=== Function nagios_probe_interface_status"
	echodebug $DEBUG " index : $index"
	echodebug $DEBUG " descr : $descr"
	echodebug $DEBUG "	operstatus : $opestatus"
	echodebug $DEBUG "	alias : $alias"

	log_to_file $DEBUG "define service{" 
    	log_to_file $DEBUG "	host_name             $HOSTNAME" 
     	log_to_file $DEBUG "	use                   $SERVICE" 
     	log_to_file $DEBUG "	service_description   $descr $alias" 
     	log_to_file $DEBUG "	check_command         check_snmp_switch!-m IF-MIB -o ifOperStatus.$index -r $operstatus" 
	log_to_file $DEBUG "}" 
	log_to_file $DEBUG "" 

	return $TRUE
}

function nagios_probe_fan_status {
	index=$1$FAN_BASE_INDEX
	BASE_OID=".1.3.6.1.4.1.9.9.13.1.4.1.3"

	# Specific unknown exception for some switch...
	MESSAGE=$(snmpget -v $SNMP_VERSION -c $SNMP_COMMUNITY $SWITCH_IP $BASE_OID.$index)
	if expr match "$MESSAGE" ".*No Such Instance currently exists at this OID" > /dev/null  ; then
		index=$1$FAN_BASE_INDEX2
	fi

	echodebug $DEBUG "=== Function nagios_probe_fan_status"
	echodebug $DEBUG " index : $index"
	
	log_to_file $DEBUG "define service{" 
     	log_to_file $DEBUG "	host_name             $HOSTNAME" 
     	log_to_file $DEBUG "	use                   $SERVICE" 
    	log_to_file $DEBUG "	service_description   Fan$1" 
    	log_to_file $DEBUG "	check_command         check_snmp_switch!-o $BASE_OID.$index -r 1" 
    	log_to_file $DEBUG "	normal_check_interval           900" 
    	log_to_file $DEBUG "	notification_interval           900" 
	log_to_file $DEBUG "}" 
	log_to_file $DEBUG "" 
	
	return $TRUE
}

function nagios_probe_power_status {
	index=$1$POWER_BASE_INDEX
	BASE_OID=".1.3.6.1.4.1.9.9.13.1.5.1.3"

	# Specific unknown exception for some switch...
	MESSAGE=$(snmpget -v $SNMP_VERSION -c $SNMP_COMMUNITY $SWITCH_IP $BASE_OID.$index)
	if expr match "$MESSAGE" ".*No Such Instance currently exists at this OID" > /dev/null  ; then
		index=$1$POWER_BASE_INDEX2
	fi
	
	echodebug $DEBUG "=== Function nagios_probe_power_status"
	echodebug $DEBUG " index : $index"

	log_to_file $DEBUG "define service{" 
     	log_to_file $DEBUG "	host_name             $HOSTNAME" 
     	log_to_file $DEBUG "	use                   $SERVICE" 
    	log_to_file $DEBUG "	service_description   Power$1" 
    	log_to_file $DEBUG "	check_command         check_snmp_switch!-o $BASE_OID.$index -r 1" 
    	log_to_file $DEBUG "	normal_check_interval           900" 
    	log_to_file $DEBUG "	notification_interval           900" 
	log_to_file $DEBUG "}" 
	log_to_file $DEBUG "" 

	return $TRUE
}

function nagios_probe_temperature_status {
	index=$1$TEMPERATURE_BASE_INDEX
	BASE_OID=".1.3.6.1.4.1.9.9.13.1.3.1.6"

	# Specific unknown exception for some switch...
	MESSAGE=$(snmpget -v $SNMP_VERSION -c $SNMP_COMMUNITY $SWITCH_IP $BASE_OID.$index)
	if expr match "$MESSAGE" ".*No Such Instance currently exists at this OID" > /dev/null  ; then
		index=$1$TEMPERATURE_BASE_INDEX2
		# Specific unknown exception for some switch...
		MESSAGE=$(snmpget -v $SNMP_VERSION -c $SNMP_COMMUNITY $SWITCH_IP $BASE_OID.$index)
		if expr match "$MESSAGE" ".*No Such Instance currently exists at this OID" > /dev/null  ; then
			index=$1$TEMPERATURE_BASE_INDEX3
		fi
	fi

	echodebug $DEBUG "=== Function nagios_probe_temperature_status"
	echodebug $DEBUG " index : $index"

	log_to_file $DEBUG "define service{" 
     	log_to_file $DEBUG "	host_name             $HOSTNAME" 
     	log_to_file $DEBUG "	use                   $SERVICE" 
    	log_to_file $DEBUG "	service_description   Temperature$1" 
    	log_to_file $DEBUG "	check_command         check_snmp_switch!-o $BASE_OID.$index -r 1" 
    	log_to_file $DEBUG "	normal_check_interval           900" 
    	log_to_file $DEBUG "	notification_interval           900" 
	log_to_file $DEBUG "}" 
	log_to_file $DEBUG "" 

	return $TRUE
}

function nagios_probe_system_decription {
	
	echodebug $DEBUG "=== Function nagios_probe_system_status"

	log_to_file $DEBUG "define service{" 
     	log_to_file $DEBUG "	host_name             $HOSTNAME" 
     	log_to_file $DEBUG "	use                   $SERVICE" 
    	log_to_file $DEBUG "	service_description   System Description" 
    	log_to_file $DEBUG "	check_command        check_snmp!$OID_sysDescr" 
    	log_to_file $DEBUG "	normal_check_interval           900" 
    	log_to_file $DEBUG "	notification_interval           900" 
	log_to_file $DEBUG "}" 
	log_to_file $DEBUG "" 

	return $TRUE
}

function nagios_probe_snmp_trap {
	
	echodebug $DEBUG "=== Function nagios_probe_system_status"

	log_to_file $DEBUG "define service{" 
     	log_to_file $DEBUG "	host_name             $HOSTNAME" 
     	log_to_file $DEBUG "	use                   snmptrap-service" 
	log_to_file $DEBUG "}" 
	log_to_file $DEBUG "" 

	return $TRUE
}

function copy_nagios_conf_file {

	echodebug $DEBUG "=== Function copy_nagios_conf_file"
	echodebug $DEBUG "NAGIOS_CONF : $1"
	echodebug $DEBUG "NEW_NAGIOS_CONF : $2"

	NAGIOS_CONF=$1
	if [ ! -f $NAGIOS_CONF ]; then
		echo "$NAGIOS_CONF not found !!!"
		exit $FALSE
	fi

	NEW_NAGIOS_CONF=$2

	if ! cp -f $NAGIOS_CONF $NEW_NAGIOS_CONF; then
		echo "Unable to copy $NAGIOS_CONF !!!"
		exit $FALSE
	fi

	return $TRUE
}

function clean_nagios_conf {

	echodebug $DEBUG "=== Function clean_nagios_conf"
	echodebug $DEBUG "	NAGIOS_CONF : $1"
	echodebug $DEBUG "	START : $2"
	echodebug $DEBUG "	STOP : $3"

	if  [ ! -f $NAGIOS_CONF ]; then
		echo "$NAGIOS_CONF nto found !!!"
		exit $FALSE
	fi

	NAGIOS_CONF=$1
	START="$2"
	STOP="$3"
	
	if ! sed -i -e "/$START/,/$STOP/d" $NAGIOS_CONF ; then
		echo "Unable to remove lines from $NAGIOS_CONF"
		exit $FALSE
	fi
	
	echodebug $DEBUG "==="
	
	return $TRUE
}

function put_limit_nagios_conf {

	echodebug $DEBUG "=== Function put_limit_nagios_conf"
	echodebug $DEBUG "	NAGIOS_CONF : $1"
	echodebug $DEBUG "	START : $2"
	echodebug $DEBUG "	STOP : $3"

	NAGIOS_CONF="$1"
	START="$2"
	STOP="$3"
	if [ ! -f $MAP ]; then
		echo "$NAGIOS_CONF not found !!!"
		exit $FALSE
	fi

	# ADD FIRST LINE
	if ! sed -i "1i $START" $NAGIOS_CONF; then
	echo "Could not add first line $START to $NAGIOS_CONF !!!"
		exit $FALSE
	fi

	# ADD LAST LINE
	if ! sed -i -e "\$a $STOP" $NAGIOS_CONF; then
		echo "Could not add last line $STOP to $NAGIOS_CONF !!!"
		exit $FALSE
	fi

	echodebug $DEBUG "==="

	return $TRUE
}


function append_to_nagios_conf {
	
	echodebug $DEBUG "=== Function append_to_nagios_conf"
	echodebug $DEBUG "	TMP_NAGIOS_CONF : $1"
	echodebug $DEBUG "	NEW_NAGIOS_CONF : $2"

	TMP_NAGIOS_CONF="$1"
	NEW_NAGIOS_CONF="$2"

	if [ ! -f $TMP_NAGIOS_CONF ]; then
		echo "$TMP_NAGIOS_CONF not found !!!"
		exit $FALSE
	fi
	
	if [ ! -f $NEW_NAGIOS_CONF ]; then
		echo "$NEW_NAGIOS_CONF not found !!!"
		exit $FALSE
	fi

	if ! cat $TMP_NAGIOS_CONF >> $NEW_NAGIOS_CONF; then
		echo "Unable to append $TMP_NAGIOS_CONF to $NEW_NAGIOS_CONF !!!"
		exit $FALSE
	fi

	if ! rm -f $TMP_NAGIOS_CONF; then
		echo "Unable to remove $TMP_NAGIOS_CONF !!!"
		exit $FALSE
	fi
	
	echodebug $DEBUG "==="

	return $TRUE
}

function get_hostname_from_nagios_conf {
	echodebug $DEBUG "=== Function get_hostname_from_nagios_conf"
	echodebug $DEBUG "	NAGIOS_CONF : $1"

	NAGIOS_CONF=$1

	HOSTNAME=$(grep host_name $NAGIOS_CONF | tail -1 | awk '{print $2}')

	echo "HOSTNAME : "$HOSTNAME

	echodebug $DEBUG "==="

	return $TRUE
}

function get_ip_from_nagios_conf {
	echodebug $DEBUG "=== Function get_ip_from_nagios_conf"
	echodebug $DEBUG "	NAGIOS_CONF : $1"

	NAGIOS_CONF=$1

	SWITCH_IP=$(grep address $NAGIOS_CONF | tail -1 |awk '{print $2}')

	echo "SWITCH_IP : "$SWITCH_IP

	echodebug $DEBUG "==="

	return $TRUE
}

function echodebug {
	level=$1
	messages="$2"

	if [ $level -gt 0 ]; then
		echo "$messages"
	fi

	return $TRUE
}

function log_to_file {
	echodebug $DEBUG "=== Function log_to_file"
	echodebug $DEBUG "	level : $1"	
	echodebug $DEBUG "	message : $2"
	echodebug $DEBUG "	logfile : $3"

	if [ ! "$1" ]; then 
		level=0
	else
		level=$1
	fi

	if [ ! "$2" ]; then
		message=""
	else
		message="$2"
	fi

	if [ ! "$3" ]; then
		logfile=$TMP_NAGIOS_CONF_FILE
	else
		logfile=$3
	fi

	if [ $DEBUG -eq 0 ]; then
		echo "$message" >> $logfile
	else
		echo "$message" | tee -a $logfile
	fi

	echodebug $DEBUG "==="

	return $TRUE
}

###################
# ########## INPUT PARAMETERS #########
parse_input_parameters "$@" 

get_hostname_from_nagios_conf $NAGIOS_CONF_FILE
get_ip_from_nagios_conf $NAGIOS_CONF_FILE

cisco_product_identifier="$(snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION $SWITCH_IP ${OID_sysObjectID} | sed -e 's/.*= OID: //')"
echodebug 1 "Product Identifier : "${cisco_product_identifier}

echodebug $DEBUG "HOSTNAME : $HOSTNAME"
echodebug $DEBUG "SWITCH_IP : $SWITCH_IP"
echodebug $DEBUG "SNMP_COMMUNITY : $SNMP_COMMUNITY"
echodebug $DEBUG "SNMP_VERSION : $SNMP_VERSION"

##################

copy_nagios_conf_file $NAGIOS_CONF_FILE $NEW_NAGIOS_CONF_FILE

clean_nagios_conf $NEW_NAGIOS_CONF_FILE "$START" "$STOP"

echodebug 1 "=== Loop over possible switches in stack ==="

# Get System Description
nagios_probe_system_decription

# SNMP TRAP
nagios_probe_snmp_trap

# Loop over possible stack size
for stack_id in $(seq 1 $MAX_STACK_SIZE); do
	echodebug 1 "=== stack_id : $stack_id"

	switch_doesnt_exists=$(snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION $SWITCH_IP .1.3.6.1.4.1.9.9.13.1.4.1.3.${stack_id}${FAN_BASE_INDEX} | grep 'No Such Instance currently exists at this OID' | wc -l )
	if [ $switch_doesnt_exists -ne 0 ]; then
		switch_doesnt_exists=$(snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION $SWITCH_IP .1.3.6.1.4.1.9.9.13.1.4.1.3.${stack_id}${FAN_BASE_INDEX2} | grep 'No Such Instance currently exists at this OID' | wc -l )
	fi

	if [ $switch_doesnt_exists -eq 0 ]; then
		#########################
		#
		# Fan Status
		#
		#########################
		nagios_probe_fan_status $stack_id
		#########################
		#
		# Power Status
		#
		#########################
		nagios_probe_power_status $stack_id
		#########################
		#
		# Temperature Status
		#
		#########################
		nagios_probe_temperature_status $stack_id
	else
		echodebug 1 "--> end of stack !!!"
		break
	fi
done

#########################
#
# Interface Status
#
#########################
# Get Interface ID
INTERFACE_ID_LIST=$(snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION $SWITCH_IP $OID_ifIndex | sed -e 's/^.*INTEGER: //g' | xargs)
echodebug 1 "INTERFACE_ID_LIST : $INTERFACE_ID_LIST"

for ifIndex in $INTERFACE_ID_LIST; do
	echodebug 1 "=== ifIndex : $ifIndex"

	# Remove non standard interface
	if [ $ifIndex -lt 9999 ] && [ "${cisco_product_identifier}" != "${Cisco6500}" ]; then
		echodebug 1 "--> non \"standard\" interface --> skip"
		continue
	fi
	
	ifAdminStatus=$(snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION $SWITCH_IP ${OID_ifAdminStatus}.$ifIndex | sed -e 's/^.*(//g' -e 's/)$//g')
	echodebug $DEBUG "ifAdminStatus : $ifAdminStatus"

	ifOperStatus=$(snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION $SWITCH_IP ${OID_ifOperStatus}.$ifIndex | sed -e 's/^.*(//g' -e 's/)$//g')
	echodebug $DEBUG "ifOperStatus : $ifOperStatus"

	ifAlias=$(snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION $SWITCH_IP ${OID_ifAlias}.$ifIndex | sed -e 's/^.*STRING: //g' | sed -e 's/"//g')
	echodebug 1 "ifAlias : $ifAlias"
	
	ifDescr=$(snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION $SWITCH_IP ${OID_ifDescr}.$ifIndex | sed -e 's/^.*STRING: //g')
	echodebug 1 "ifDescr : $ifDescr"

	# Remove down interface
	if [ $ifOperStatus -ne 1 ]; then
		echodebug 1 "--> interface is down --> skip"
		continue
	fi
	# Remove non GigabitEthernet interface
	if ! expr match "$ifDescr" ".*GigabitEthernet.*" > /dev/null; then
		echodebug 1 "--> non GigabitEthernet interface --> skip"
		continue
	fi
	# Remove interface with empty description (alias)
	if [ "$ifAlias" == "" ]; then
		echodebug 1 "--> interface alias description is empty --> skip"
		continue
	fi
	nagios_probe_interface_status $ifIndex $ifDescr $ifOperStatus $ifAlias
done

echodebug 1 "=== add limit to nagios conf"
put_limit_nagios_conf $TMP_NAGIOS_CONF_FILE "$START" "$STOP"

echodebug 1 "=== append probe to $NEW_NAGIOS_CONF_FILE"
append_to_nagios_conf $TMP_NAGIOS_CONF_FILE $NEW_NAGIOS_CONF_FILE
echo ""
echo "=== Do you want to overwrite nagios configration file by this newly generated one ? (y/n)"
read -t 10 OVERWRITE

###### Copie des fichiers
case ${OVERWRITE:=n} in
 "y")
        echo "$NAGIOS_CONF_FILE overwritten by $NEW_NAGIOS_CONF_FILE ..."
	cp $NEW_NAGIOS_CONF_FILE $NAGIOS_CONF_FILE
 ;;
 "n")
        echo "$NAGIOS_CONF_FILE has not been overwritten."
 ;;
 *)
        echo "Choix non possible, annulation..."
        exit 1
 ;;
esac

exit $TRUE
