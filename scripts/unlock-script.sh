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
-a, --address         Address of host to unlock
--port                Port of host to unlock
-u, --user	      User to ssh to
-i, --identity        SSH identity to use
-p, --password        Password to unlock with
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
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  flag=0
  param=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -p | --password)
      password="${2-}"
      shift
      ;;
    -u | --user)
      user="${2-}"
      shift
      ;;
    -a | --address)
      address="${2-}"
      shift
      ;;
    -i | --identity)
      identity="${2-}"
      shift
      ;;
    --port)
      port="${2-}"
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
  [[ -z "${port-}" ]] && die "Missing required parameter: port"
  [[ -z "${user-}" ]] && die "Missing required parameter: user"
  [[ -z "${identity-}" ]] && die "Missing required parameter: identity"
  [[ -z "${password-}" ]] && die "Missing required parameter: password"

  return 0
}

parse_params "$@"
setup_colors

msg "Testing if SSH is running"
nc -zv "${address}" "${port}"
msg "SSH is running, executing cryptunlock"
ssh "${user}"@"${address}" -i "${identity}" -p "${port}" -t "echo -n ${password} | cryptroot-unlock"
