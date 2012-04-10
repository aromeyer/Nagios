#!/bin/bash

# DEBUG LEVEL
DEBUG=0

# Boolean
TRUE=0
FALSE=1

#########################
#
# Netapp Configuration
#
#########################
SSH_USER='root'
SSH_PASSWORD='XXX'

DISKUSED_WARNING_THRESHOLD=80
DISKUSED_CRITICAL_THRESHOLD=90

# Nagios config file
START="#=== START AUTOMATICALLY GENERATED CONF"
STOP="#=== STOP AUTOMATICALLY GENERATED CONF"

########## FUNCTION #########
function usage {
	echodebug $DEBUG "=== Function usage"

	echo "usage : $(basename $0) [Nagios netapp configuration file] {[SSH user] [SSH password]}"
	echo "	- Nagios netapp configuration file : mandatory - path to the nagios configuration file of the netapp"
	echo "	- SSH user : optionnal - default to root"
	echo "	- SSH password : optionnal - default to XXX"

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
		SSH_USER="root"
	else
		SNMP_COMMUNITY=$2
	fi
	
	if [ ! $3 ]; then
		SSH_PASSWORD="XXX"
	else
		SNMP_VERSION=$3
	fi

	return $TRUE
}

function nagios_probe_fan_status {
	echodebug $DEBUG "=== Function nagios_probe_fan_status"
	
	log_to_file $DEBUG "define service{" 
     	log_to_file $DEBUG "	host_name             $HOSTNAME" 
    	log_to_file $DEBUG "	use         service-check-netapp-fan"
	log_to_file $DEBUG "}" 
	log_to_file $DEBUG "" 
	
	return $TRUE
}

function nagios_probe_power_status {
	echodebug $DEBUG "=== Function nagios_probe_power_status"

	log_to_file $DEBUG "define service{" 
     	log_to_file $DEBUG "	host_name             $HOSTNAME" 
    	log_to_file $DEBUG "	use         service-check-netapp-powersupply " 
	log_to_file $DEBUG "}" 
	log_to_file $DEBUG "" 

	return $TRUE
}

function nagios_probe_temperature_status {
	echodebug $DEBUG "=== Function nagios_probe_temperature_status"

	log_to_file $DEBUG "define service{" 
     	log_to_file $DEBUG "	host_name             $HOSTNAME" 
    	log_to_file $DEBUG "	use         service-check-netapp-temperature" 
	log_to_file $DEBUG "}" 
	log_to_file $DEBUG "" 

	return $TRUE
}

function nagios_probe_netapp_disk_status {

	echodebug $DEBUG "=== Function nagios_probe_netapp_disk_status"
	volume=$1
	echodebug $DEBUG "volume : $1"

	log_to_file $DEBUG "define service{" 
     	log_to_file $DEBUG "	host_name             $HOSTNAME" 
	log_to_file $DEBUG "	use                   generic-service"
    	log_to_file $DEBUG "	service_description   $volume" 
    	log_to_file $DEBUG "	check_command			  check-netapp-disk!$volume!$DISKUSED_WARNING_THRESHOLD!$DISKUSED_WARNING_THRESHOLD" 
    	log_to_file $DEBUG "	normal_check_interval           900"
    	log_to_file $DEBUG "	notification_interval           900"
#    	log_to_file $DEBUG "	register            0"
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

	HOSTNAME=$(grep host_name $NAGIOS_CONF | head -1 | awk '{print $2}')

	echo "HOSTNAME : "$HOSTNAME

	echodebug $DEBUG "==="

	return $TRUE
}

function get_ip_from_nagios_conf {
	echodebug $DEBUG "=== Function get_ip_from_nagios_conf"
	echodebug $DEBUG "	NAGIOS_CONF : $1"

	NAGIOS_CONF=$1

	NETAPP_IP=$(grep address $NAGIOS_CONF | tail -1 |awk '{print $2}')

	echo "NETAPP_IP : "$NETAPP_IP

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

echodebug $DEBUG "HOSTNAME : $HOSTNAME"
echodebug $DEBUG "NETAPP_IP : $NETAPP_IP"
echodebug $DEBUG "SSH_USER : $SSH_USER"
echodebug $DEBUG "SSH_PASSWORD : $SSH_PASSWORD"

##################

copy_nagios_conf_file $NAGIOS_CONF_FILE $NEW_NAGIOS_CONF_FILE

clean_nagios_conf $NEW_NAGIOS_CONF_FILE "$START" "$STOP"

#########################
#
# Fan Status
#
#########################
nagios_probe_fan_status 
#########################
#
# Power Status
#
#########################
nagios_probe_power_status 
#########################
#
# Temperature Status
#
#########################
nagios_probe_temperature_status 

# # Loop over available cifs shares
volume_list=$(ssh $SSH_USER@$NETAPP_IP "vol status" | grep raid_dp |awk '{print $1}' | xargs)
ERROR_CODE=$?
if [ $ERROR_CODE != 0 ]; then
	echo "Unable to connect to $NETAPP_IP "
	exit $FALSE
fi
for volume in $volume_list ; do
	echo "	---> volume: "$volume
	volume=$(echo $volume | sed -e 's/$/\//')
	volume="/vol/$volume"

	nagios_probe_netapp_disk_status $volume
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
