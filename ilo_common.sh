#!/bin/bash

DEV_CD=1
DEV_FDD=2
DEV_HD=3
DEV_USB=4
DEV_PXE=5

ILO2_HOSTS="mrl gnd yda dmb"
ILO4_HOSTS="mtn lmn bmn neo str kgn"
PRIMARY_CONTROL_HOSTS="str"
SECONDARY_CONTROL_HOSTS="mrl"
TERNARY_CONTROL_HOSTS="gnd"
CONTROL_HOSTS="$PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS"
COMPUTE_HOSTS="mtn lmn bmn neo"

ALL_HOSTS="manhattan lawnmowerman bowman kerrigan neo strange merlin gandalf yoda dumbledore"
UNDERCLOUD_HOSTS="kerrigan dumbledore"
OVERCLOUD_HOSTS="manhattan lawnmowerman bowman neo merlin gandalf yoda"

ALL_HOSTS_MINUS_ADMIN="manhattan lawnmowerman bowman kerrigan neo strange merlin gandalf dumbledore"
