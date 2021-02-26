#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. $MACRO_DIR/../control_scripts.sh


SELFNAME_SHORT=`hostname | awk -F'.' '{print $1}'`
NAME_SUFFIX=`echo $SELFNAME_SHORT | awk -F'-' '{print $2}'`
[[ $NAME_SUFFIX != "admin" ]] || {
  echo "RUN THIS SCRIPT FROM AN ADMIN OS!"
  echo "This host will back itself up without reboots."
  return 1
}

# This will boot to default all OTHER hosts - RUN FROM ADMIN SERVER (yoda?)
ilo_power_off_these_hosts "$ALL_HOSTS" # WILL SKIP LOCALHOST
os_control_boot_to_target_installation_these_hosts default "$ALL_HOSTS" # WILL SKIP LOCALHOST
. $MACRO_DIR/00_hosts_update.sh
