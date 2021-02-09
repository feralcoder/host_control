#!/bin/bash -x
echo "$2"
SOURCE="${BASH_SOURCE[0]}"
echo $(dirname $SOURCE)


# Run only this file to include the others:
. ilo_common.sh
. ilo_power.sh
. ilo_boot.sh
. ilo_boot_target.sh

. ssh_control.sh  
. os_control.sh  
. undercloud_control.sh
. stack_control.sh  

echo $my_dir
