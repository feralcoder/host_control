#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

HOSTS="kgn neo bmn lmn mtn dmb"
SRC_PREFIX=b
DEST_PREFIX=a

admin_control_clone_and_fix_labels_these_hosts $SRC_PREFIX $DEST_PREFIX "$HOSTS"
