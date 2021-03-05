#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

# This script is suitable to run after the post-install host scripts
#   (00a_new_install_no_admin_key.sh  00b_new_admin_key_on_host.sh  00c_new_install_with_existing_admin_key.sh)

REPO_HOST=dumbledore

NOW=`date +%Y%m%d-%H%M%S`

HOSTS=$1
[[ $HOSTS == "" ]] && {
  echo "No hosts provided.  You must provide a list of hosts to update."
  exit 1
}

host_control_setup_host_access () {
  local HOSTS=$1

  echo; echo "REFETCHING LOCAL KNOWN HOSTKEYS FOR $HOSTS"
  # Make sure this host recognizes all others
  ssh_control_refetch_hostkey_these_hosts "$HOSTS"
  echo; echo "RESETTING ADMIN KEYS on $HOSTS"
  # Redistribute admin pubkeys to cliff/root users everywhere
  ssh_control_distribute_admin_key_these_hosts "$HOSTS"

  echo; echo "REFETCHING ILO KEYS LOCALLY"
  ilo_control_refetch_ilo_hostkey_these_hosts "$HOSTS"
}


host_control_updates () {
  local HOSTS=$1

  echo; echo "REPOINTING YUM TO LOCAL MIRROR ON $HOSTS"
  os_control_checkout_repofetcher `hostname`
  os_control_repoint_repos_to_feralcoder_these_hosts "$HOSTS"

  echo; echo "UPDATING ADMIN ENV ON $HOSTS"
  for HOST in $HOSTS; do
    admin_control_bootstrap_admin $HOST
  done
  ssh_control_run_as_user_these_hosts cliff "~/CODE/feralcoder/workstation/update.sh" "$HOSTS"

  echo; echo "UPDATING GIT REPOS EVERYWHERE"
  git_control_pull_push_these_hosts "$HOSTS" 2>/dev/null

  # Serialize to not DOS ILO's and HOSTS
  for HOST in $HOSTS; do
    echo; echo "REFETCHING HOST KEYS on $HOST"
    ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$HOSTS\"" $HOST 2>/dev/null
    echo; echo "Getting ILO hostkeys on $HOST"
    ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$HOSTS\"" $HOST 2>/dev/null
  done
}


host_updates () {
  local HOSTS=$1

  echo; echo "UPDATING YUM ON $HOSTS, see output in logfile /tmp/yum_update_$NOW.log"
  ssh_control_run_as_user_these_hosts root "dnf -y upgrade | tee /tmp/yum_update_$NOW.log" "$HOSTS"
  
  echo; echo "UPDATING GRUB ON $HOSTS"
  admin_control_fix_grub_these_hosts "$HOSTS"
}



SUDO_PASS_FILE=`admin_control_get_sudo_password`
[[ -f ~/.password ]] || { mv $SUDO_PASS_FILE ~/.password && SUDO_PASS_FILE=~/.password ; }
host_control_setup_host_access "$HOSTS"
os_control_setup_repo_mirror $REPO_HOST
host_control_updates "$HOSTS"
host_updates "$HOSTS"

[[ $SUDO_PASS_FILE != ~/.password ]] && rm $SUDO_PASS_FILE
