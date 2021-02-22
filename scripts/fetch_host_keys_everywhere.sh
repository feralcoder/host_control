#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../control_scripts.sh

for host in $ALL_HOSTS; do
  ssh_control_run_as_user cliff "cd ~cliff/CODE/feralcoder/host_control; . control_scripts.sh ; ilo_control_refetch_ilo_hostkey_these_hosts \"$ALL_HOSTS\"; ssh_control_refetch_hostkey_these_hosts  \"$ALL_HOSTS\"" $host
  ssh_control_run_as_user root "cd ~cliff/CODE/feralcoder/host_control; . control_scripts.sh ; ilo_control_refetch_ilo_hostkey_these_hosts \"$ALL_HOSTS\"; ssh_control_refetch_hostkey_these_hosts  \"$ALL_HOSTS\"" $host
done

