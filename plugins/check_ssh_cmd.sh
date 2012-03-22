#!/usr/bin/env bash

# This script may be used to define Nagios services. 
# It is similar to the external plugin 'check_mysql_query'
# Todo
# - test for string '-H' & '-u' option value: at present time I only test for existence

DEBUG=0                             # CONF todo
LOGGED=0                             # CONF todo
LOG_AFI=/tmp/$THIS_BASENAME.log
THIS_BASENAME=$(basename $0)
VERSION=1.0
FALSE=1
TRUE=0
SSH_BIN=/usr/bin/ssh
STATUS_CRITICAL=2
STATUS_WARNING=1
STATUS_DEFAULT=0
SVC="SSH_CMD"

function man(){
  msg="$THIS_BASENAME $VERSION
A Nagios plugin developped by RDC

This program checks a SSH command against threshold levels. It will exit with the following statuses:
  2: 'critical' threshold reached or SSH error
  1: 'warning' threshold reached
  0: default status: nothing happened
  "
  out "$msg" 1
  usage
}

function usage(){
    msg="Usage:
  $THIS_BASENAME [-hVl] [-d <debug level>] [-c <critical threshold>] [-w <warning thresh>] -H <host> -u <user> <SSH_cmd> 

Options:
 -h
    Print detailed help screen
 -V
    Print version information
 -l 
    log all out() call
 -d 
    Debug level: 0 -> prod, 1 -> test
 -w 
    (optional) Warning integer threshold
 -c
    (optional) Critical integer threshold
 -H 
    (required) Host name, IP Address, or unix socket (must be an absolute path)
 -u 
    (required) Username to login with

Exemple:
  check_ssh_cmd.sh -c1 -urdc -Hzm18 'find '\$MALL_DATA_ROOT'/run -type f -iname \"*pid*\" -mmin +\$((60 * 4)) -printf \"%f\\n\" | wc -l'

The command returned value should be an int, to be compared against thresholds.
For extra security, create a user with minimal access.
"
  out "$msg" 1
  return 0
}

function out(){ 
  is_forced=${2:-0}
  (( is_forced || DEBUG)) && echo -e "$1"
  (( LOGGED)) && echo -e "$1" >> $LOG_AFI
  return 0
}

function err(){ 
  is_forced=${2:-0}
  (( is_forced || DEBUG)) && echo -e "ERROR: $1" 1>&2
  (( is_forced)) && usage
  return 0
}

function init(){
  local opt
  while getopts ':lhVd:w:c:H:u:' opt
  do
    case $opt in
    h) man
       exit $TRUE
       ;;
    V) out "$THIS_BASENAME version $VERSION" 1
       exit $TRUE
       ;;
    d) is_int_alt "$OPTARG" || { err "'-d' value should be an int" 1; return 18; }
       DEBUG="$OPTARG"
       ;;
    l) LOGGED=1
       > $LOG_AFI   # empty the log file before any append
       ;;
    w) is_int_alt "$OPTARG" || { err "'-w' value should be an int" 1; return 14; }
       WARNING_THRESH="$OPTARG"
       ;;
    c) is_int_alt "$OPTARG" || { err "'-c' value should be an int" 1; return 15; }
       CRITICAL_THRESH="$OPTARG"
       ;;
    H) test "$OPTARG" || { err "'-H' value should be a string" 1; return 16; }
       HOST="$OPTARG"
       ;;
    u) test "$OPTARG" || { err "'-u' value should be a string" 1; return 17; }
       LOGIN="$OPTARG"
       ;;
   \?) err "unknown option: -$OPTARG" 1; exit 10
       ;;
    esac
  done
  shift $(( OPTIND - 1))
  CMD="$1"
  test "$CMD"   || { err "missing command" 1; return 11; }
  test "$HOST"  || { err "missing host"    1; return 12; }
  test "$LOGIN" || { err "missing login"   1; return 13; }
  out "CMD= $CMD, WARNING_THRESH= $WARNING_THRESH, CRITICAL_THRESH= $CRITICAL_THRESH, HOST= $HOST, LOGIN= $LOGIN, DEBUG= $DEBUG"
  return 0
}

# Is arg an integer
# This code is compatible with Bash version < 2.39
function is_int_alt(){
  [ $# -eq 1 ] || return 1;                  # only 1 arg
  test "0" == "$1" && return 0;              # is it 0
  local a=${1//,/}        # convert to int (decimal separator depends on current locale)
  test "$1" == "$a" || return 2              # $a should have the same value as $1
  (( "$a" + 0)) 2> /dev/null && return 0;    # add 0: this fails when $a isn't a number
  return 1;
}

function main(){
  local r
  r=$( $SSH_BIN "$LOGIN"@"$HOST" "$CMD" 2> /dev/null)
  local ssh_exit_status=$?
  if(( 0 != $ssh_exit_status))
  then 
    out "SSH failed with exit status= $ssh_exit_status"
    if(( 255 != $ssh_exit_status))
    then
      err "the command executed by SSH is incorrect"
      exit_status_=$STATUS_CRITICAL
    fi
    return 0
  fi
  out "SSH's returned value= $r"
  if test "$CRITICAL_THRESH" && (( CRITICAL_THRESH <= r))
  then
    out "$SVC CRITICAL: returned $r" 1
    exit_status_=$STATUS_CRITICAL
  elif test "$WARNING_THRESH" && (( WARNING_THRESH <= r))
  then
    out "$SVC WARNING: returned $r" 1
    exit_status_=$STATUS_WARNING
  else
    out "$SVC OK: returned $r" 1
  fi
  return 0
}

init "$@" || { err "init() failed: returned $?"; exit $FALSE; }
exit_status_=$STATUS_DEFAULT
main      || { err "main() failed: returned $?"; exit $FALSE; }
exit $exit_status_
