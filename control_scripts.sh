#!/bin/bash -x
CONTROL_SOURCE="${BASH_SOURCE[0]}"
CONTROL_DIR=$( dirname $CONTROL_SOURCE )

# Run only this file to include the others:
. $CONTROL_DIR/ilo_common.sh
. $CONTROL_DIR/ilo_control.sh
. $CONTROL_DIR/ilo_power.sh
. $CONTROL_DIR/ilo_boot.sh
. $CONTROL_DIR/ilo_boot_target.sh

. $CONTROL_DIR/ssh_control.sh  
. $CONTROL_DIR/os_control.sh  
. $CONTROL_DIR/undercloud_control.sh
. $CONTROL_DIR/stack_control.sh  

ILO2_HOSTS="mrl gnd yda dmb"
ILO4_HOSTS="mtn lmn bmn neo str kgn"
PRIMARY_CONTROL_HOSTS="str"
SECONDARY_CONTROL_HOSTS="mrl"
TERNARY_CONTROL_HOSTS="gnd"
CONTROL_HOSTS="$PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS"
COMPUTE_HOSTS="mtn lmn bmn neo"

ALL_HOSTS="mtn lmn bmn kgn neo str mrl gnd yda dmb"
UNDERCLOUD_HOSTS="dmb"
OVERCLOUD_HOSTS="mtn lmn bmn neo mrl gnd str kgn"
ADMIN_HOSTS="yda"
ALL_HOSTS_MINUS_ADMIN="mtn lmn bmn kgn neo str mrl gnd dmb"

ALL_HOSTS_LONGNAMES="manhattan lawnmowerman bowman kerrigan neo strange merlin gandalf yoda dumbledore"
