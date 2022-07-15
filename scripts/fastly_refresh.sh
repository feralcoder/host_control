#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../control_scripts.sh

USER_DIR=$(
  if [[ -d ~cliff ]]; then
    echo ~cliff
  elif [[ -d ~feralcoder ]]; then
    echo ~feralcoder
  else
    echo ''
  fi
)
if [[ $USER_DIR == '' ]]; then
  echo "Unable to determine admin user on system.  Not 'cliff' or 'feralcoder'."
  exit
fi


WIKI_CHECKOUTS="$USER_DIR/CODE/feralcoder/workstation.wiki $USER_DIR/CODE/feralcoder/shared.wiki"
for WIKI in $WIKI_CHECKOUTS; do
  cd $WIKI
  git pull
  wiki_control_warm_fastly_cache
done
