#!/bin/bash
DEBUG="$1"

TRUE=0
FALSE=1

NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2

#####################
# replace the SRV list with your own machines
SRV="127.0.0.1"

if [ ! -z "$DEBUG" ]; then
	echo "Serveur list  : "$SRV
fi
#####################

# RBL list
#ddnsbl.internetdefensesystems.com 
#access.redhawk.org
RBL="bl.spamcop.net cbl.abuseat.org b.barracudacentral.org dnsbl.invaluement.com dnsbl.sorbs.net http.dnsbl.sorbs.net dul.dnsbl.sorbs.net misc.dnsbl.sorbs.net smtp.dnsbl.sorbs.net socks.dnsbl.sorbs.net spam.dnsbl.sorbs.net web.dnsbl.sorbs.net zombie.dnsbl.sorbs.net dnsbl-1.uceprotect.net dnsbl-2.uceprotect.net dnsbl-3.uceprotect.net pbl.spamhaus.org sbl.spamhaus.org xbl.spamhaus.org zen.spamhaus.org bl.spamcannibal.org psbl.surriel.com ubl.unsubscore.com dnsbl.njabl.org combined.njabl.org rbl.spamlab.com dnsbl.ahbl.org ircbl.ahbl.org dyna.spamrats.com noptr.spamrats.com spam.spamrats.com cbl.anti-spam.org.cn cdl.anti-spam.org.cn dnsbl.inps.de drone.abuse.ch httpbl.abuse.ch dul.ru korea.services.net short.rbl.jp virus.rbl.jp spamrbl.imp.ch wormrbl.imp.ch virbl.bit.nl rbl.suresupport.com dsn.rfc-ignorant.org ips.backscatterer.org spamguard.leadmon.net opm.tornevall.org netblock.pedantic.org black.uribl.com grey.uribl.com multi.surbl.org ix.dnsbl.manitu.net tor.dan.me.uk rbl.efnetrbl.org relays.mail-abuse.org blackholes.mail-abuse.org rbl-plus.mail-abuse.org dnsbl.dronebl.org db.wpbl.info rbl.interserver.net query.senderbase.org bogons.cymru.com"
if [ ! -z "$DEBUG" ]; then
	echo "RBL list : "$RBL
fi

# Test each IP over the RBL list
function test_ip {
	local server_ip=$1
	local reverse_ip=$2

	local summary_file="/tmp/mail-rbl-check."$server_ip".log"
	rm -f $summary_file

	local nmatch=0

	for rbl in $RBL; do
		echo "=== testing $server ($server_ip) against $rbl ===" >> $summary_file
		if [ ! -z "$DEBUG" ]; then
			echo "=== testing $server ($server_ip) against $rbl ==="
		fi
		result=$(dig +short $reverse_ip.$rbl)
		
		echo $result >> $summary_file

		if [ ! -z "$result" ]; then
			let nmatch++
			echo "	---> $server ($server_ip) is in $rbl with code $result" >> $summary_file
# 			if [ ! -z "$DEBUG" ]; then
				echo "	---> $server ($server_ip) is in $rbl with code $result"
# 			fi
		else 
			echo "	---> negative" >> $summary_file
			if [ ! -z "$DEBUG" ]; then
				echo "	---> negative"
			fi
		fi
	done

	exit $nmatch
}

# Loop over internal server
id=0
declare -A process_pid_list
for server in $SRV; do
	if [[ $server =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		ip=$server 
	else
		ip=$(dig +short $server | tail -1)
	fi
	r_ip=$(echo $ip|awk -F"." '{for(i=NF;i>0;i--) printf i!=1?$i".":"%s",$i}')

	test_ip $ip $r_ip&
	pid=$!

	process_pid_list[${pid}]=$ip
	
	let id++
done

if [ ! -z "$DEBUG" ]; then
	echo "process_pid_list : "${!process_pid_list[@]}
fi

# 
# global_status=0
# for pid in ${!process_pid_list[@]} ; do
# 	wait $pid 2>&1 > /dev/null
# 	rc=$?
# 	if [ $rc -ne 0 ] && [ $rc -ne 127 ] ; then
# 		process_pid_status[${pid}]=$rc;
# 		let global_status++
# 		if [ ! -z "$DEBUG" ]; then
# 			echo "$rc - ${process_pid_list[${pid}]} is listed into at least one RBL"
# 		fi
# 	fi
# done


# if [ $global_status -gt 0 ]; then
# 	bl_ips=""
# 	for pid in ${!process_pid_status[@]}; do
# 		bl_ips="$bl_ips ${process_pid_list[$pid]}"
# 	done
# 
# 	echo "Black listed ips : $bl_ips"
# fi

FAIL=0
for job in $(jobs -p); do
	wait $job || let "FAIL+=$?"
done

if [ $FAIL -gt 0 ]; then
	exit $NAGIOS_CRITICAL
fi

exit $NAGIOS_OK
