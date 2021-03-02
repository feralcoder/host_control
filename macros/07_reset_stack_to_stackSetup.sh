#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

$MACRO_DIR/09_reset_everything.sh 02_Stack_Setup a "$STACK_HOSTS"
