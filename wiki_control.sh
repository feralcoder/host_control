#!/bin/bash

[[ $CHECK_IMAGES == "" ]] && {
  [[ $DEBUG == "" ]] || echo "wiki_control: Defaulting CHECK_IMAGES to 'false'"
  CHECK_IMAGES=false
}

wiki_control_get_pages_with () {
  local SEARCH_FOR=$1
  grep "$SEARCH_FOR" * | awk -F'.' '{print $1 ".md"}' | sort | uniq
}

wiki_control_page_exists () {
  local WHICH_WIKI=$1 PAGE=$2
  if [[ ! -d /tmp/$WHICH_WIKI.wiki.$$ ]]; then
    git clone https://feralcoder:`cat ~/.git_password`@github.com/feralcoder/$WHICH_WIKI.wiki.git /tmp/$WHICH_WIKI.wiki.$$
  fi

  if [[ -f /tmp/$WHICH_WIKI.wiki.$$/$PAGE ]]; then
    return 0
  else
    return 1
  fi
}

wiki_control_find_broken_external_links () {
  local PAGES="$1"

  [[ $PAGES == "" ]] && PAGES=*
  local -A EXT_LINK_RESOLVED

  local LINK PAGE LINKS CHECK_IMAGES FERALCODER_PRIVATE_WIKI HTTP_CODE WHICH_WIKI
  TEST=$(for PAGE in $PAGES; do
    [[ $DEBUG ]] && echo "Checking PAGE $PAGE" 1>&2
    LINKS=$(cat $PAGE | sed -r 's/http(s*):/\nhttp\1:/gi' | grep -i '^http' | sed 's/]].*//g' | sed 's/".*//g' | sed 's/<.*//g' | sed 's/ .*//g' | sed 's/\.$//g')
    [[ $CHECK_IMAGES == "false" ]] && { LINKS=$(echo $LINKS | grep -vi 'jpg\|gif'); }
    TEST=$(for LINK in $LINKS; do
      [[ $DEBUG ]] && echo "Checking LINK $LINK" 1>&2
      if [[ ${EXT_LINK_RESOLVED[$LINK]} == "" ]] ; then
        FERALCODER_PRIVATE_WIKI=$(echo $LINK | grep -i 'http[s]*://[a-z.]*github.com/feralcoder/\(bootstrap-scripts\|workstation\)/wiki')
        if [[ $FERALCODER_PRIVATE_WIKI != "" ]]; then
          WHICH_WIKI=$(echo $LINK | sed -E 's/.*feralcoder\/([a-z]*)\/wiki.*/\1/g')
          if [[ $WHICH_WIKI != "" ]]; then
            PAGE=$(echo $LINK | sed "s/.*feralcoder\/$WHICH_WIKI\/wiki\///g" | sed 's/%3A/:/g').md
            if (wiki_control_page_exists $WHICH_WIKI $PAGE); then
              HTTP_CODE=200
            else
              HTTP_CODE=404
            fi
          else
            HTTP_CODE=$(curl -sIkL  -H 'Authorization: token $(cat ~/CODE/feralcoder/host_control/github_token)' -H 'Accept: application/vnd.github.v3.raw'  $LINK | grep 'HTTP/[1-4]' | awk '{print $2}')
          fi
        else
          HTTP_CODE=$(curl -sIkL  $LINK | grep 'HTTP/[1-4]' | awk '{print $2}')
        fi
        EXT_LINK_RESOLVED[$LINK]=$HTTP_CODE
      fi
      for x in "${!EXT_LINK_RESOLVED[@]}"; do printf "[%s]=%s\n" "$x" "${EXT_LINK_RESOLVED[$x]}" ; done
    done)
    echo "$TEST" | grep -v '^$' > /tmp/URLHASH_$$
    cat /tmp/URLHASH_$$

    while read line; do
      KEY=$(echo $line | sed -E 's/\[(.*)\].*/\1/g')
      VALUE=$(echo $line | awk -F'=' '{print $2}')
      if [[ $KEY == "" ]]; then continue; fi
      EXT_LINK_RESOLVED[$KEY]=$VALUE
    done <<< "$(cat /tmp/URLHASH_$$)"

    echo; echo; echo;
    [[ $DEBUG ]] && echo $(for x in "${!EXT_LINK_RESOLVED[@]}"; do printf "[%s]=%s\n" "$x" "${EXT_LINK_RESOLVED[$x]}" ; done)|wc 1>&2
  done)
  echo "$TEST" | grep -v '^$' > /tmp/URLHASH_$$

  while read line; do
    KEY=$(echo $line | sed -E 's/\[(.*)\].*/\1/g')
    VALUE=$(echo $line | awk -F'=' '{print $2}')
    if [[ $KEY == "" ]]; then continue; fi
    EXT_LINK_RESOLVED[$KEY]=$VALUE
  done <<< "$(cat /tmp/URLHASH_$$)"
  echo; echo; echo;
  [[ $DEBUG ]] && echo $(for x in "${!EXT_LINK_RESOLVED[@]}"; do printf "[%s]=%s\n" "$x" "${EXT_LINK_RESOLVED[$x]}" ; done)|wc 1>&2
  sleep 3

  declare -A HTTP_CODES
  TEST=$(for x in "${!EXT_LINK_RESOLVED[@]}"; do
    echo ${EXT_LINK_RESOLVED[$x]}
  done)
  CODES=`echo "$TEST" | sort | uniq`
  [[ $DEBUG ]] && echo $CODES 1>&2

  for CODE in $CODES; do
    LINKS=$(for LINK in "${!EXT_LINK_RESOLVED[@]}"; do
      if [[ ${EXT_LINK_RESOLVED[$LINK]} == $CODE ]]; then
        echo $LINK
      fi
    done)
    echo "CODE $CODE for the following links:"
    echo "$LINKS"
    echo; echo;
  done


  rm -rf /tmp/*.wiki.$$
}
