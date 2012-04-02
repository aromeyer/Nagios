#!/usr/bin/perl 

# nagios: -epn

################################################################################
# check_redis - Nagios Plugin for Redis checks.
#
# @author  farmer.luo at gmail.com
# @date    2010-05-12
# @license GPL v2
#
# check_nagios.pl -h <redis host> -p <redis port> -w <warning time> -c <critica time>
#
# Run the script need:
#
# perl -MCPAN -e shell
# install Redis
#
################################################################################

BEGIN{push @INC, '/usr/lib/nagios/plugins/';}

use strict;
use warnings;
use Redis;
use File::Basename;
use utils qw($TIMEOUT %ERRORS &print_revision &support); 
use Time::Local;
use vars qw($opt_h); # Redis 主机
use vars qw($opt_p); # Redis 端口
use vars qw($opt_w); # 超过这个时间发出警告
use vars qw($opt_c); # 超过这个时间发出严重警告
use vars qw($opt_b);
use Getopt::Std;

$opt_h = "";
$opt_p = "6379";
$opt_w = 5;
$opt_c = 10;
$opt_b = 0;
my $r = "";
my $redis_info;
my $redis_nagios_key = 'redis_nagios_key';
my $redis_key_value = 'nagios_test';

getopt('hpwcd');

if ( $opt_h eq "" ) {
	help();
	exit(1);
}

my $start = time();

redis_connect();

redis_get_info();

# print $@;
if ( $@ ) {
	print "UNKNOWN - cann't connect to redis server:" . $opt_h . ".";
	exit $ERRORS{"UNKNOWN"};
}

if ( redis_select() ) {
	print "UNKNOWN - db :" . $opt_b . ", unknown redis db.";
	exit $ERRORS{"UNKNOWN"};
}

if ( redis_set() ) {
	print "WARNING - redis server:" . $opt_h . ",set key error.";
	exit $ERRORS{"WARNING"};
}

if ( redis_get() ) {
	print "WARNING - redis server:" . $opt_h . ",get key error.";
	exit $ERRORS{"WARNING"};
}

if ( redis_del() ) {
	print "WARNING - redis server:" . $opt_h . ",del key error.";
	exit $ERRORS{"WARNING"};
}

#sleep(3);
my $stop = time();

my $run = $stop - $start;

if ( $run > $opt_c ) {
	
	print "CRITICAL - redis server(" . $opt_h . ") run for " . $run . " seconds!";
	redis_quit();
	exit $ERRORS{"CRITICAL"};
	
} elsif ( $run > $opt_w ) {
	
	print "WARNING - redis server(" . $opt_h . ") run for " . $run . " seconds!";
	redis_quit();
	exit $ERRORS{"WARNING"};
	
} else {
	
	redis_print_info();
	redis_quit();
	exit $ERRORS{"OK"};
	
}


sub help{
	
	die "Usage:\n" , basename( $0 ) ,  " -h hostname -p port -w warning time -c critical time -d down time -b redis db id\n"
	
}

sub redis_connect{
	
	my $redis_hp = $opt_h . ":" . $opt_p;
	
	eval{ $r = Redis->new( server => $redis_hp , debug => 0); };
	
}

sub redis_select{

	$r->select("$opt_b") || return 1;

	return 0;
}

sub redis_set{

	$r->set($redis_nagios_key => "$redis_key_value") || return 1;

	return 0;
}

sub redis_get{
	my $value = $r->get("$redis_nagios_key") || return 1;
	
	if ( "$value" ne "$redis_key_value" ) {
		return 1;
	}

	return 0;
}

sub redis_del{
	
	$r->del("$redis_nagios_key") || return 1;
	
	return 0;
}

sub redis_get_info{
	
	$redis_info = $r->info;
}

sub redis_print_info{
	
	print "OK - redis server(" . $opt_h . ") info:";
	
	while ( my ($key, $value) = each(%$redis_info) ) {
	    print "$key => $value, ";
	}

}

sub redis_quit{
	
	$r->quit();
	
}
