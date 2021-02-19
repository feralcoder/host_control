#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

UPDATED_OS_LINK=$1

[[ $UPDATED_OS_LINK == "" ]] && {
  UPDATED_OS_LINK=dumbledoreB_01_CentOS_8_2_Updated
}

. $THIS_SOURCE/01a_restore_base_OS.sh $UPDATED_OS_LINK
. $THIS_SOURCE/01b_update_base_OS.sh
. $THIS_SOURCE/01c_backup_base_OS.sh $UPDATED_OS_LINK
