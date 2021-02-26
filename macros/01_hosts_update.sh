#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh


setup_yum_repos () {
  os_control_checkout_repofetcher dmb
  ssh_control_run_as_user root "/home/cliff/CODE/feralcoder/repo-fetcher/setup.sh" dmb
}



get_sudo_password () {
  local PASSWORD

  # if ~/.password exists and works, use it
  [[ -f ~/.password ]] && {
    cat ~/.password | sudo -k -S ls >/dev/null 2>&1
    if [[ $? == 0 ]] ; then
      echo ~/.password
      return
    fi
  }

  # either ~.password doesn't exiist, or it doesn't work
  read -s -p "Enter Sudo Password: " PASSWORD
  touch /tmp/password_$$
  chmod 600 /tmp/password_$$
  echo $PASSWORD > /tmp/password_$$
  echo /tmp/password_$$
}



host_control_updates () {
  # Make sure this host can reach all others
  ssh_control_refetch_hostkey_these_hosts "$ALL_HOSTS"

  echo; echo "UPDATING cliff ADMIN ENV FROM workstation/update.sh EVERYWHERE"
  ssh_control_sync_as_user_these_hosts cliff ~/.password ~/.password "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts cliff "./CODE/feralcoder/workstation/update.sh" "$ALL_HOSTS"

  echo; echo "UPDATING REPOS EVERYWHERE"
  git_control_pull_push_these_hosts "$ALL_HOSTS" 2>/dev/null

#
#  echo; echo "REFETCHING ILO KEYS EVERYWHERE"
#  # Serialize to not hose ILO's
#  for HOST in $ALL_HOSTS; do
#     echo; echo "Getting ILO hostkeys on $HOST"
#     ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST 2>/dev/null
#  done
#

  echo; echo "REFETCHING HOST KEYS EVERYWHERE"
  ssh_control_run_as_user_these_hosts cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS\"" "$ALL_HOSTS" 2>/dev/null
}


host_updates () {
  os_control_checkout_repofetcher yda
  os_control_repoint_repos_to_feralcoder_these_hosts "$ALL_HOSTS"
  ssh_control_run_as_user root "dnf -y upgrade" "$ALL_HOSTS"
  
  admin_control_fix_grub_these_hosts "$ALL_HOSTS"
}



SUDO_PASS_FILE=`get_sudo_password`
[[ -f ~/.password ]] || { mv $SUDO_PASS_FILE ~/.password && SUDO_PASS_FILE=~/.password ; }
host_control_updates
setup_yum_repos
host_updates

[[ $SUDO_PASS_FILE != ~/.password ]] && rm $SUDO_PASS_FILE
