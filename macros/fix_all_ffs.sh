#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh


for HOST in $ALL_HOSTS; do
  admin_control_bootstrap_admin $HOST
done

git_control_pull_push_these_hosts "$ALL_HOSTS"
ssh_control_run_as_user_these_hosts cliff "~/CODE/feralcoder/workstation/update.sh" "$ALL_HOSTS"
ssh_control_run_as_user_these_hosts root "rm /etc/ssh/ssh_host_\*/ -rf" "$ALL_HOSTS"
admin_control_fix_grub_these_hosts "$ALL_HOSTS"

for HOST in $ALL_HOSTS; do
  echo; echo "REFETCHING HOST KEYS on $HOST"
  ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST 2>/dev/null
  echo; echo "Getting ILO hostkeys on $HOST"
  ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST 2>/dev/null
done
