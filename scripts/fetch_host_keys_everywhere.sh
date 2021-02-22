#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../control_scripts.sh

ssh_control_run_as_user_these_hosts cliff "cd CODE/feralcoder/host_control; . control_scripts.sh ; for host in $ALL_HOSTS; do ilo_control_refetch_ilo_hostkey \"$ALL_HOSTS\"" $host; ssh_control_refetch_hostkey  \"$ALL_HOSTS\"" $host; done"
ssh_control_run_as_user_these_hosts root "cd CODE/feralcoder/host_control; . control_scripts.sh ; for host in $ALL_HOSTS; do ilo_control_refetch_ilo_hostkey \"$ALL_HOSTS\"" $host; ssh_control_refetch_hostkey  \"$ALL_HOSTS\"" $host; done"
