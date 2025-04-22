#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat << EOF # remove the space between << and EOF, this is due to web plugin issue
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -p param_value arg1 [arg2...]

Script description here.

Available options:

-h, --help            Print this help and exit
-v, --verbose         Print script debug info
-a, --address         Address of host to replicate to
-t, --token           Expected token on the server
-p, --password_file   Password file to unlock with
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "$(date) - ${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  timeout=10

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -a | --address)
      address="${2-}"
      shift
      ;;
    -t | --token)
      token="${2-}"
      shift
      ;;
    -p | --password_file)
      password_file="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  [[ -z "${address-}" ]] && die "Missing required parameter: address"
  [[ -z "${token-}" ]] && die "Missing required parameter: token"
  [[ -z "${password_file-}" ]] && die "Missing required parameter: password_file"

  return 0
}

parse_params "$@"
setup_colors

challenge=$(curl -s "${address}/token" | jq -r '.token')

if [[ "${challenge}" != "${token}" ]]; then
    die "Token mismatch"
fi

exists=$(curl -s "${address}/exists" | jq -r '.exists')

if [[ "true" = "${exists}" ]]; then
    die "Password exists" 0
fi

password=$(cat "${password_file}")
success=$(curl -s -X POST -d "password=${password}" "${address}/password" | jq -r '.success')

if [[ "true" != "${success}" ]]; then
    die "Failed to send password"
fi

msg "Replicated"
