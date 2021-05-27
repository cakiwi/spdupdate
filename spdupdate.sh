#!/bin/bash
set -o pipefail

# Variables
# SPDUPDATE_HOST              host:port of SPD  defaults to 127.0.0.1:4280 (optional)
# SPDUPDATE_QUIET             If defined suggested settings will not be displayed, default prints suggestions (optional)
# SPDUPDATE_NOPROMPT          If defined suggested settings will be appied without prompt, default prompts for response (optional)
# SPDUPDATE_APIPASSWORD       Api Password for SPD, overrides SPDUPDATE_APIPASSWORD_FILE (optional)
# SPDUPDATE_APIPASSWORD_FILE  Path to apipasswordfile, defaults to ${SCPRIME_DATA_DIR}/apipassword $HOME/.scprime/apipassword (optional)

# check if dependencies are available
for prog in curl jq
do 
  
  if ! which ${prog} 2>&1 >/dev/null ; then 
    echo ERROR: Required program '${prog}' is not installed >&2
    exit 1
  fi
done

# read apipassword from default file
if [[ -r ${SPDUPDATE_APIPASSWORD_FILE:=${SCPRIME_DATA_DIR:=~/.scprime}/apipassword} ]] ; then 
  file_apipassword=$(head -n1 ${SPDUPDATE_APIPASSWORD_FILE})
fi

if ! [[ ${SPDUPDATE_APIPASSWORD:=${file_apipassword}} ]] ; then 
  echo WARNING: Empty APIPASSWORD >&2
fi

spd_host="${SPDUPDATE_HOST:=127.0.0.1:4280}"

# get public key from spd api
pubkey=$(curl --silent --fail --max-time 2 ${spd_host}/host -A ScPrime-Agent | jq -r '.publickey.key' | base64 -d | od -t x1 -A n -v | tr -dc '[:xdigit:]' )
# get suggested settings from metrics.scpri.me
suggested_settings=$(curl --silent --fail --max-time 2 "https://metrics.scpri.me/suggestedsettings?publickey=${pubkey}" | jq -r '.|to_entries|map("\(.key)=\(.value|tostring)")|join("&")') 

# display suggested setting and prompt
if ! [[ ${SPDUPDATE_QUIET} ]] ; then 
  echo ${suggested_settings} | sed 's/&/\n/g'
  if ! [[ ${SPDUPDATE_NOPROMPT} ]] ; then 
    read -p "Continue and update spd (y/n) " response
    [[ ${response^} != 'Y' ]] && exit 125
  fi
fi

# post the update to spd api
if curl --silent --fail --max-time 2 ${spd_host}/host -A ScPrime-Agent -XPOST -u":${SPDUPDATE_APIPASSWORD:=${file_apipassword}}" -d "${suggested_settings}"
  then
  echo Update Success
else
  echo Update Failed
  exit 1
fi
