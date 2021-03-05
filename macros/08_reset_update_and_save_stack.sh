#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

$MACRO_DIR/07_reset_stack_to_OS.sh
$MACRO_DIR/02a_hosts_update.sh
$MACRO_DIR/07_backup_stack_to_OS.sh
