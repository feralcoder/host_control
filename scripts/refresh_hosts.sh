#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../control_scripts.sh


ilo_control_refetch_ilo_hostkey_these_hosts "$ALL_HOSTS"
ssh_control_refetch_hostkey_these_hosts "$ALL_HOSTS"
cd ~cliff/CODE/feralcoder/; for i in *; do cd $i; git pull; cd ..; done
$THIS_SOURCE/fix_and_freshen_repos_everywhere.sh
