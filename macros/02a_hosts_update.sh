#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

# This script is suitable to run after the post-install host scripts
#   (00a_new_install_no_admin_key.sh  00b_new_admin_key_on_host.sh  00c_new_install_with_existing_admin_key.sh)

REPO_HOST=dumbledore


HOSTS=$1
[[ $HOSTS == "" ]] && {
  echo "No hosts provided.  You must provide a list of hosts to update."
  return 1
}

host_control_refresh_host_access () {
  local HOSTS=$1

  echo; echo "RESETTING HOST / ADMIN KEYS on $HOSTS"
  # Make sure this host recognizes all others
  ssh_control_refetch_hostkey_these_hosts "$HOSTS"
  # Redistribute admin pubkeys to cliff/root users everywhere
  ssh_control_distribute_admin_key_these_hosts "$HOSTS"
}

host_control_updates () {
  local HOSTS=$1

  echo; echo "UPDATING cliff ADMIN ENV FROM workstation/update.sh EVERYWHERE"
  for HOST in $HOSTS; do
    admin_control_bootstrap_admin $HOST
    ssh_control_run_as_user_these_hosts cliff "./CODE/feralcoder/workstation/update.sh" "$HOSTS"
  done
  ssh_control_sync_as_user_these_hosts cliff ~/.password ~/.password "$HOSTS"
  ssh_control_run_as_user_these_hosts cliff "./CODE/feralcoder/workstation/update.sh" "$HOSTS"

  echo; echo "UPDATING REPOS EVERYWHERE"
  git_control_pull_push_these_hosts "$HOSTS" 2>/dev/null

#
#  echo; echo "REFETCHING ILO KEYS EVERYWHERE"
#  # Serialize to not hose ILO's
#  for HOST in $HOSTS; do
#     echo; echo "Getting ILO hostkeys on $HOST"
#     ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$HOSTS\"" $HOST 2>/dev/null
#  done
#

  echo; echo "REFETCHING HOST KEYS EVERYWHERE"
  ssh_control_run_as_user_these_hosts cliff "ssh_control_refetch_hostkey_these_hosts \"$HOSTS\"" "$HOSTS" 2>/dev/null
}


host_updates () {
  local HOSTS=$1

  os_control_checkout_repofetcher `hostame`
  os_control_repoint_repos_to_feralcoder_these_hosts "$HOSTS"
  ssh_control_run_as_user root "dnf -y upgrade" "$HOSTS"
  
  admin_control_fix_grub_these_hosts "$HOSTS"
}



SUDO_PASS_FILE=`admin_control_get_sudo_password`
[[ -f ~/.password ]] || { mv $SUDO_PASS_FILE ~/.password && SUDO_PASS_FILE=~/.password ; }
host_control_refresh_host_access "$HOSTS"
host_control_updates "$HOSTS"
os_control_setup_repo_mirror $REPO_HOST
host_updates "$HOSTS"

[[ $SUDO_PASS_FILE != ~/.password ]] && rm $SUDO_PASS_FILE
