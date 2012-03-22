#!/bin/bash

DEBUG=0

TRUE=0
FALSE=1

USER="nagios"
PASSWD="nagios"

START_YEAR=2009
START_MONTH=8
START_DAY=1
START_HOUR=0
START_MIN=0
START_SECOND=0

END_YEAR=2009
END_MONTH=9
END_DAY=1
END_HOUR=24
END_MIN=0
END_SECOND=0

SERVER=127.0.0.1
TIMEOUT=60

# HOSTGROUPS
PROCESS_HOSTGROUP=1
HOSTGROUP_LIST="batch front-servers"
HOSTGROUP_FILTER="grep Average | sed -e \"s/^.*hostUP'>//\" -e 's/%.*$//'"

# SERVICEGROUPS
PROCESS_SERVICEGROUP=1
SERVICEGROUP_LIST="databases nfs"
SERVICEGROUP_FILTER="grep Average | grep serviceOK | sed -e \"s/^.*serviceOK'>//\" -e 's/%.*$//'"

while getopts "hd:s:e:" option; do
	case $option in
		d)
  			if expr match "$OPTARG" '^[0-9]*$' &> /dev/null; then
				DEBUG=$OPTARG
			else
				echo "Invalid DEBUG number $OPTARG : DEBUG set to 0 !!!"
				DEBUG=0
    			fi
  		;;
  		e)
			if expr match "$OPTARG" '^[0-9]\{1,2\}-[0-9]\{1,2\}-[0-9]\{4\}$' &> /dev/null; then
				END_DAY=$(echo $OPTARG | cut -d - -f 1)
				END_MONTH=$(echo $OPTARG | cut -d - -f 2)
				END_YEAR=$(echo $OPTARG | cut -d - -f 3)
			else
				echo "Invalid END PERIOD DATE $OPTARG !!! The format is DD-MM-YYYY."
				exit 1
			fi
		;;
		s)
			if expr match "$OPTARG" '^[0-9]\{1,2\}-[0-9]\{1,2\}-[0-9]\{4\}$' &> /dev/null; then
				START_DAY=$(echo $OPTARG | cut -d - -f 1)
				START_MONTH=$(echo $OPTARG | cut -d - -f 2)
				START_YEAR=$(echo $OPTARG | cut -d - -f 3)
			else
				echo "Invalid START PERIOD DATE $OPTARG !!! The format is DD-MM-YYYY."
				exit 1
			fi
		;;
		h)
			echo "Usage : bash nagios_availabiolty_report.sh [OPTIONS]"
			echo " "
			echo "Get availabilty report on hostgroups and servicegroups for a given period."
			echo " "
			echo "Available command line OPTIONS : "
			echo "	-d : debug level (DEFAULT : $DEBUG)"
			echo "	-h : print this help"
			echo "	-e : end period (DEFUALT : $HOST)"
			echo "	-s : start period (DEFAULT : "$SITE")"

			exit 0
		;;
		?)
			echo "Unknown option : -$OPTARG"
			wrong_option=1
		;;
	esac
done

# Print choosen parameters
if [ $DEBUG -gt 0 ]; then
	echo "==========================================="
	echo "Deploy Nagios configuration"
	echo "Parameters : "
	echo "SERVER : "$SERVER
	echo "PERIOD - FROM $START_DAY-$START_MONTH-$START_YEAR TO $END_DAY-$END_MONTH-$END_YEAR"
	echo "HOSTGROUP_LIST : "$HOSTGROUP_LIST
	echo "SERVICEGROUP_LIST : "$SERVICEGROUP_LIST
	echo "==========================================="
fi

echo "==== NAGIOS AVAILABILTY REPORT ===="
echo "PERIOD - FROM $START_DAY-$START_MONTH-$START_YEAR TO $END_DAY-$END_MONTH-$END_YEAR"

if [ $PROCESS_HOSTGROUP -eq 1 ]; then
	csv_hostgroup='date'
	csv_qos="$START_DAY-$START_MONTH-$START_YEAR/$END_DAY-$END_MONTH-$END_YEAR"
	echo "=== HOSTGROUPS"
	for hostgroup in $HOSTGROUP_LIST ; do
		COMMAND='curl --silent --max-time '$TIMEOUT' --user '$USER':'$PASSWD' http://'$SERVER'/nagios/cgi-bin/avail.cgi?show_log_entries\=\&hostgroup\='$hostgroup'\&timeperiod\=custom\&smon\='$START_MONTH'\&sday\='$START_DAY'\&syear\='$START_YEAR'\&shour\='$START_HOUR'\&smin\='$START_MIN'\&ssec\='$START_SECOND'\&emon\='$END_MONTH'\&eday\=1\&eyear\='$END_YEAR'\&ehour\='$END_HOUR'\&emin\='$END_MIN'\&esec\='$END_SECOND'\&rpttimeperiod\=\&assumeinitialstates\=yes\&assumestateretention\=yes\&assumestatesduringnotrunning\=yes\&includesoftstates\=no\&initialassumedhoststate\=1\&initialassumedservicestate\=1\&backtrack\=4 |'$HOSTGROUP_FILTER

		if [ $DEBUG -gt 0 ]; then
			echo $COMMAND
		fi

		qos=$(eval "$COMMAND")
		csv_hostgroup="$csv_hostgroup $hostgroup"
		csv_qos=$csv_qos' '$qos

		echo '--> '$hostgroup' : '$qos'%'


	done
	echo $csv_hostgroup
	echo $csv_qos
fi

if [ $PROCESS_SERVICEGROUP -eq 1 ]; then
	csv_servicegroup='date'
	csv_qos="$START_DAY-$START_MONTH-$START_YEAR/$END_DAY-$END_MONTH-$END_YEAR"
	echo "=== SERVICEGROUPS"
	for servicegroup in $SERVICEGROUP_LIST ; do
		COMMAND='curl --silent --max-time '$TIMEOUT' --user '$USER':'$PASSWD' http://'$SERVER'/nagios/cgi-bin/avail.cgi?show_log_entries\=\&servicegroup\='$servicegroup'\&timeperiod\=custom\&smon\='$START_MONTH'\&sday\='$START_DAY'\&syear\='$START_YEAR'\&shour\='$START_HOUR'\&smin\='$START_MIN'\&ssec\='$START_SECOND'\&emon\='$END_MONTH'\&eday\=1\&eyear\='$END_YEAR'\&ehour\='$END_HOUR'\&emin\='$END_MIN'\&esec\='$END_SECOND'\&rpttimeperiod\=\&assumeinitialstates\=yes\&assumestateretention\=yes\&assumestatesduringnotrunning\=yes\&includesoftstates\=no\&initialassumedhoststate\=1\&initialassumedservicestate\=1\&backtrack\=4 |'$SERVICEGROUP_FILTER

		if [ $DEBUG -gt 0 ]; then
			echo $COMMAND
		fi
		qos=$(eval "$COMMAND")

		csv_servicegroup="$csv_servicegroup $servicegroup"
		csv_qos=$csv_qos' '$qos

		echo '--> '$servicegroup' : '$qos'%'

	done

	echo $csv_servicegroup
	echo $csv_qos
fi

exit $TRUE
