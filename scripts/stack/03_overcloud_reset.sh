#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

SKIP_IP=true

ilo_power_off_these_hosts "$OVERCLOUD_HOSTS"

[[ $SKIP_IP == "" ]] && {
  # Toggle boot drives to stack, if necessary
  ilo_boot_set_onetimeboot_these_hosts ip "$(group_logic_intersection "$ILO4_HOSTS" "$OVERCLOUD_HOSTS")"
  ilo_power_on_these_hosts "$(group_logic_intersection "$ILO4_HOSTS" "$OVERCLOUD_HOSTS")"
  # Replace drives in Gen6 hosts manually

  PROCEED=""
  while [[ $PROCEED != "yes" ]]; do
    read -p "Ready?  Type 'yes' (in lowercase) to proceed:" PROCEED
  done
  ilo_power_off_these_hosts "$OVERCLOUD_HOSTS"
}

os_control_boot_to_target_installation_these_hosts admin "$OVERCLOUD_HOSTS"

PRE_CMD="rm /tmp/stack_drive_hosed*; echo ''>/tmp/stack_drive_hosed_$$"
FIND_DRIVE_CMD="STACK_DRIVE=\`blkid | grep img-rootfs | awk '{print \$1}' | sed -e 's/.://g'\`"
DD_CMD="dd if=/dev/zero of=\$STACK_DRIVE bs=1M count=1024 conv=sync && echo true > /tmp/stack_drive_hosed_$$"

ssh_control_run_as_user_these_hosts root "$PRE_CMD; $FIND_DRIVE_CMD; $DD_CMD && echo true > /tmp/stack_drive_hosed_$$" "$OVERCLOUD_HOSTS"

ssh_control_run_as_user_these_hosts root "if [[ \`cat /tmp/stack_drive_hosed_$$\` == '' ]]; then echo \`hostname\` NEEDS MANUAL HOSING.; fi" "$OVERCLOUD_HOSTS"

echo "We're done here!"
