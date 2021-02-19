#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

os_control_boot_to_target_installation default dmb

# Upload CentOS 8.3 Image
# NEED KEY PAIRS
# NEED SECURITY GROUPS
# NEED EXTERNAL BRIDGE SETUP
# NEED EXTERNAL AND INTERNAL NETWORKS
# NEED ROUTER SETUP
# NEED FLAVORS
# NEED AVAILABILITY ZONES

# ssh_control_run_as_user root "su - stack -c '. overcloudrc; openstack image create centos8.3.2011-generic --disk-format qcow2 --container-format bare  --public --file /registry/stack_downloads/stock_downloads/CentOS-8-GenericCloud-8.3.2011-20201204.2.x86_64.qcow2'" dmb
# ssh_control_run_as_user root "su - stack -c '. overcloudrc; openstack flavor create --ram 512 --disk 10 --swap 0 --vcpus 2 --public two.half.ten'" dmb

