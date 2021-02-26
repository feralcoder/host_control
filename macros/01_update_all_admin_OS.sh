#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. $MACRO_DIR/../control_scripts.sh


# This will boot to admin all OTHER hosts - RUN FROM ADMIN SERVER (yoda?)
ilo_power_off_these_hosts "$ALL_HOSTS" # WILL SKIP LOCALHOST
os_control_boot_to_target_installation_these_hosts admin "$ALL_HOSTS" # WILL SKIP LOCALHOST
. $MACRO_DIR/00_hosts_update.sh
