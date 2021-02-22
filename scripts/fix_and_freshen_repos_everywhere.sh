#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../control_scripts.sh

ssh_control_run_as_user_these_hosts root "chown -R cliff:cliff /home/cliff/CODE" "$ALL_HOSTS"
ssh_control_sync_as_user_these_hosts cliff /home/cliff/.git_password /home/cliff/.git_password "$ALL_HOSTS"

for REPO in bootstrap-scripts  host_control  kolla-ansible  workstation  workstation.wiki; do
  CODE_PATH=/home/cliff/CODE/feralcoder/$REPO
  FIXPASS_CMD='sed -i "s/feralcoder:[^@]*/feralcoder:`cat ~/.git_password`/g" .git/config'
  ssh_control_run_as_user_these_hosts cliff "echo Fixing $REPO on \`hostname\`; if [[ -d $CODE_PATH ]]; then cd $CODE_PATH && $FIXPASS_CMD && git pull 2>&1; else echo $CODE_PATH DOES NOT EXIST ON \`hostname\`; fi; echo; echo" "$ALL_HOSTS"
done
