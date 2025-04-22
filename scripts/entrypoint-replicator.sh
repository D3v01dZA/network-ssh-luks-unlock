#!/bin/bash

FILE="/tmpfs/password-file"
TOKEN_FILE="/tmpfs/token-file"
LAST_REPORT_TIME_SECONDS=$(date -d 2013-07-18 +%s) # some old date

msg() {
  echo >&2 -e "$(date) - ${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

df | grep /tmpfs > /dev/null
if [[ "$?" = "1" ]]; then
    die "/tmpfs is not a tmpfs mount"
fi

[[ -z "${SLEEP_TIME-}" ]] && SLEEP_TIME=1
[[ -z "${REPLICATOR_ADDRESS-}" ]] && die "Missing required environment variable: REPLICATOR_ADDRESS"
[[ -z "${REPLICATOR_TOKEN-}" ]] && die "Missing required environment variable: REPLICATOR_TOKEN"
[[ -z "${OWN_TOKEN-}" ]] && die "Missing required environment variable: OWN_TOKEN"

msg "Replicator Address: ${REPLICATOR_ADDRESS}"

echo -n "${OWN_TOKEN}" > "${TOKEN_FILE}"

python3 /app/server.py &

while true
do
    msg "Loop start"
    if [[ -f "${FILE}" ]]; then
        # Replicate
        /app/replicate-script.sh --address "${REPLICATOR_ADDRESS}" --token "${REPLICATOR_TOKEN}" --password_file "${FILE}"
        return_code="$?"
        msg "Replicator script ended with return code ${return_code}"
    else
        msg "Password not set"
    fi
    msg "Sleeping"
    sleep "${SLEEP_TIME}"
done
