#!/bin/bash -x
CONTROL_SOURCE="${BASH_SOURCE[0]}"

# Run only this file to include the others:
. ilo_common.sh
. ilo_control.sh
. ilo_power.sh
. ilo_boot.sh
. ilo_boot_target.sh

. ssh_control.sh  
. os_control.sh  
. undercloud_control.sh
. stack_control.sh  

ILO2_HOSTS="mrl gnd yda dmb"
ILO4_HOSTS="mtn lmn bmn neo str kgn"
PRIMARY_CONTROL_HOSTS="str"
SECONDARY_CONTROL_HOSTS="mrl"
TERNARY_CONTROL_HOSTS="gnd"
CONTROL_HOSTS="$PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS"
COMPUTE_HOSTS="mtn lmn bmn neo"

ALL_HOSTS="mtn lmn bmn kgn neo str mrl gnd yda dmb"
UNDERCLOUD_HOSTS="kgn dmb"
OVERCLOUD_HOSTS="mtn lmn bmn neo mrl gnd str"

ALL_HOSTS_MINUS_ADMIN="mtn lmn bmn kgn neo str mrl gnd dmb"

ALL_HOSTS_LONGNAMES="manhattan lawnmowerman bowman kerrigan neo strange merlin gandalf yoda dumbledore"
