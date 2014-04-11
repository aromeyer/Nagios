#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long qw(:config gnu_getopt);
use Cache::Memcached;
use Nagios::Plugin;
use Data::Dumper;
use DateTime qw();

my $VERSION="0.1";
my $np;

$np = Nagios::Plugin->new(usage => "Usage: %s [--host1|-H <host>] [--port1|-P <port>] [--host2|-S <host>] [--port2|-p <port>] [ -c|--critical=<threshold> ] [ -w|--warning=<threshold>] [-?|--usage] [-V|--version] [-h|--help] [-v|--verbose] [-t|--timeout=<timeout>]",
                          version => $VERSION,
                          blurb => 'This plugin checks the availability of a memcachedb/repcached server, expecting that a slave server is sync with master, and the replication delay is not too high.',
                          license => "Brought to you AS IS, WITHOUT WARRANTY, under GPL. (C) Remi Paulmier <remi.paulmier\@gmail.com>",
                          shortname => "CHECK_MEMCACHE",
                         );

$np->add_arg(spec => 'host1|H=s',
             help => q(Check the host indicated in STRING),
             required => 0,
             default => 'localhost',
            );

$np->add_arg(spec => 'port1|P=i',
             help => q(Use the TCP port indicated in INTEGER),
             required => 0,
             default => 11211,
            );
            
$np->add_arg(spec => 'host2|S=s',
             help => q(Check the host indicated in STRING),
             required => 0,
             default => 'localhost',
            );

$np->add_arg(spec => 'port2|p=i',
             help => q(Use the TCP port indicated in INTEGER),
             required => 0,
             default => 11211,
            );

$np->add_arg(spec => 'critical|c=s',
             help => q(Exit with CRITICAL status if replication delay is greater than INTEGER),
             required => 0,
             default => 10,
            );

$np->add_arg(spec => 'warning|w=s',
             help => q(Exit with WARNING status if replication delay is greater than INTEGER),
             required => 0,
             default => 1,
            );

$np->getopts;
my $ng = $np->opts;

# manage timeout
alarm $ng->timeout;

############ Master or Slave ?
my $slavehost;
my $slaveport;
my $masterhost;
my $masterport;

# Detect master or slave host (repcached is master master but we will use the same)
my $memcache = new Cache::Memcached{ 'servers' => [ $ng->get('host1').":".$ng->get('port1') ], 'debug' => 0  };
if ( ! $memcache->stats() ) {
	$np->nagios_exit( CRITICAL, "ERROR - Cannot connect to memcache !!! - host ".$ng->get('host1').":".$ng->get('port1') );
}
if ( ! $memcache->set('test','test',0) ) {
	# Host is slave
	$slavehost = $ng->get('host1');
	$slaveport = $ng->get('port1');
	$masterhost = $ng->get('host2');
	$masterport = $ng->get('port2');
} else {
	# Host is master
	$slavehost = $ng->get('host2');
	$slaveport = $ng->get('port2');
	$masterhost = $ng->get('host1');
	$masterport = $ng->get('port1');
}
$memcache->disconnect_all();

########### Check Replication

# verbosity
my $verbose = $ng->get('verbose');

my $master_memcache;
eval {
	$master_memcache = new Cache::Memcached{ 'servers' => [ "$masterhost:$masterport" ], 'debug' => 0  };
};
if ($@) {
	$np->nagios_exit( CRITICAL, "Can't connect to master memcache $masterhost:$masterport" );
}

my $slave_memcache;
eval {
	$slave_memcache = new Cache::Memcached{ 'servers' => [ "$slavehost:$slaveport" ], 'debug' => 0  };
};
if ($@) {
	$np->nagios_exit( CRITICAL, "Can't connect to slave memcache $slavehost:$slaveport" );
}

my $master_info = $master_memcache->stats();
$master_info->{'role'} = 'master';
# print Dumper($master_memcache->stats())."\n";

my $slave_info = $slave_memcache->stats();
$slave_info->{'role'} = 'slave';
# print Dumper($slave_memcache->stats())."\n";

my $code = CRITICAL;
my $msg = "ERROR - master: ".$masterhost.":".$masterport." - slave: ".$slavehost.":".$slaveport;

# Set monitoring data
my $data = DateTime->now->strftime('%Y%m%d%H%M%S');
if ( ! $master_memcache->set('nagios',$data,10) ) {
	$msg = "ERROR - Cannot write on Master !!! - master: ".$masterhost.":".$masterport." - slave: ".$slavehost.":".$slaveport;
	$code = CRITICAL;
} else {
	my $master_value = $master_memcache->get('nagios');
	if ( $master_value ne $data ) {
		$msg = "ERROR - Incorrect write/read comparison on Master !!! - master[".$masterhost.":".$masterport."]: ".$master_value." - slave: ".$slavehost.":".$slaveport;
		$code = CRITICAL;
	} else {
		sleep(1);
		my $slave_value = $slave_memcache->get('nagios');
		if ( $slave_value ne $data ) {
			$msg = "ERROR - Incorrect write/read comparison on Slave !!! - master[".$masterhost.":".$masterport."]: ".$master_value." - slave[".$slavehost.":".$slaveport."]: ".$slave_value ;
			$code = CRITICAL;
		} else {
			$msg = "Everything is OK - master[".$masterhost.":".$masterport."]: ".$master_value." - slave[".$slavehost.":".$slaveport."]: ".$slave_value ;
			$code = OK;
		}
	}
}

$np->nagios_exit( $code, $msg );