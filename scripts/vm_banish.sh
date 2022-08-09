#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../control_scripts.sh

VM_NAME=$1

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

if [[ "$VM_NAME" == "" ]]; then
  echo "You must specify VM to operate."
  return
elif [[ "$VM_NAME" == zeratul ]]; then
  WEB_HOOK=https://eac23562-bfe2-485a-a3c8-75781b177934.webhook.eus.azure-automation.net/webhooks?token=XXE2qfMubFEFQZuMP23agkmI3mNxG56QJ%2fC62dd0Wr0%3d
elif [[ "$VM_NAME" == q ]]; then
  WEB_HOOK=https://eac23562-bfe2-485a-a3c8-75781b177934.webhook.eus.azure-automation.net/webhooks?token=L0jRiw9YHclxX3U6RgsWpjsYmPN1sflmBF2YvHArKkU%3d
else
  echo "Unknown VM name: $VM_NAME"
  return
fi

wget --method=POST $WEB_HOOK
SLEEP=30
TRIES=20

for TRY in $(seq 1 $TRIES); do
  echo Try $TRY of $TRIES.
  SHUTDOWN_LOCK=/tmp/no_shutdown
  ssh -o ConnectTimeout=3 $VM_NAME.feralcoder.org hostname && {
    ssh -o ConnectTimeout=3 $VM_NAME.feralcoder.org rm $SHUTDOWN_LOCK
    echo $VM_NAME WILL GO
    return
  }
  echo $VM_NAME still not reachable.
  echo Sleeping for $SLEEP seconds.
  sleep $SLEEP
done


#Q Summon/Banish: 
#https://eac23562-bfe2-485a-a3c8-75781b177934.webhook.eus.azure-automation.net/webhooks?token=weXNB9K2yhYeJVuYizrqG2wBz%2bzFJsYplnmr88T4rdM%3d
#Zeratul Summon/Banish: 
#https://eac23562-bfe2-485a-a3c8-75781b177934.webhook.eus.azure-automation.net/webhooks?token=cbG6s7wln9Z3u0%2b8QnjlaEMc6bFsxdvwt%2bDgmM%2fDIn0%3d
#
#Q Start:
#https://eac23562-bfe2-485a-a3c8-75781b177934.webhook.eus.azure-automation.net/webhooks?token=RjQu6CSlcf8%2fmIOvI6rniRd3nXf4e29EFqvO7Gnqh08%3d
#Zeratul Start:
#https://eac23562-bfe2-485a-a3c8-75781b177934.webhook.eus.azure-automation.net/webhooks?token=iKkAsSKDb%2frfjZHio%2b35iYgPa%2bfHZ4P1eAY2vyFofdc%3d
#
#
#Q CleanUp:
#https://eac23562-bfe2-485a-a3c8-75781b177934.webhook.eus.azure-automation.net/webhooks?token=L0jRiw9YHclxX3U6RgsWpjsYmPN1sflmBF2YvHArKkU%3d
#Zeratul CleanUp:
#https://eac23562-bfe2-485a-a3c8-75781b177934.webhook.eus.azure-automation.net/webhooks?token=XXE2qfMubFEFQZuMP23agkmI3mNxG56QJ%2fC62dd0Wr0%3d
