#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../control_scripts.sh

WIKI_CHECKOUTS='/home/cliff/CODE/feralcoder/workstation.git /home/cliff/CODE/feralcoder/shared.git'
for WIKI in $WIKI_CHECKOUTS; do
  cd $WIKI
  git pull
  wiki_control_warm_fastly_cache
done
