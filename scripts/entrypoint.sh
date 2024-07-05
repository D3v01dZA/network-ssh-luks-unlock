#!/bin/bash

FILE="/tmpfs/password-file"
LAST_REPORT_TIME_SECONDS=$(date -d 2013-07-18 +%s) # some old date

msg() {
  echo >&2 -e "${1-}"
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

[[ -z "${ADDRESS-}" ]] && die "Missing required environment variable: ADDRESS"
[[ -z "${PORT-}" ]] && die "Missing required environment variable: PORT"
[[ -z "${USER-}" ]] && die "Missing required environment variable: USER"
[[ -z "${IDENTITY_FILE-}" ]] && die "Missing required environment variable: IDENTITY_FILE"
[[ -z "${KNOWN_HOSTS_FILE-}" ]] && die "Missing required environment variable: KNOWN_HOSTS_FILE"
[[ -z "${HEALTH_CHECK_URL-}" ]] && die "Missing required environment variable: HEALTH_CHECK_URL"
[[ -z "${REMOVE_PASSWORD_ON_UNLOCK-}" ]] && REMOVE_PASSWORD_ON_UNLOCK=1
[[ -z "${HEALTH_CHECK_REPEAT_SECONDS-}" ]] && HEALTH_CHECK_REPEAT_SECONDS=900
[[ -z "${SLEEP_TIME-}" ]] && SLEEP_TIME=1
[[ -z "${TIMEOUT_TIME-}" ]] && TIMEOUT_TIME=10

msg "Address: ${ADDRESS}"
msg "Port: ${PORT}"
msg "User: ${USER}"
msg "Identity File: ${IDENTITY_FILE}"
msg "Known Hosts File: ${KNOWN_HOSTS_FILE}"

python3 /app/server.py &

while true
do
    echo "$(date) - Loop start"
    if [[ -f "${FILE}" ]]; then
        NOW=$(date +%s)
        NEXT_REPORT_TIME=$((${LAST_REPORT_TIME_SECONDS} + ${HEALTH_CHECK_REPEAT_SECONDS}))
        if [ ${NOW} -ge ${NEXT_REPORT_TIME} ]; then # Curl the health check url to say we have the password if we haven't in a while
            LAST_REPORT_TIME_SECONDS=${NOW}
            echo "$(date) - Healthcheck"
            curl -m 10 -s --retry 5 "${HEALTH_CHECK_URL}" 
        fi
        echo "$(date) - Unlock script start"
        /app/unlock-script.sh --address "${ADDRESS}" --port "${PORT}" --user "${USER}" --timeout "${TIMEOUT_TIME}" --identity_file "${IDENTITY_FILE}" --known_hosts_file "${KNOWN_HOSTS_FILE}" --password "$(cat "${FILE}")"
        return_code="$?"
        echo "$(date) - Unlock script ended with return code ${return_code}"
        if [[ "${return_code}" = "0" ]]; then # 0 means we succesfully unlocked
            if [[ "${REMOVE_PASSWORD_ON_UNLOCK}" = "1" ]]; then
                echo "$(date) - Deleting the password file"
                rm "${FILE}"
            else
                echo "$(date) - Not deleting the password file"
            fi
        fi
        if [[ "${return_code}" = "1" ]]; then # 1 means an unknown error so instantly fail the healthcheck
            curl -m 10 -s --retry 5 "${HEALTH_CHECK_URL}/fail"
            echo "$(date) - Healthcheck Fail"
        fi
        if [[ "${return_code}" = "3" ]]; then # 3 means we could ssh but that command failed for whatever reason so instantly fail the health check
            curl -m 10 -s --retry 5 "${HEALTH_CHECK_URL}/fail"
            echo "$(date) - Healthcheck Fail"
        fi
    else
        echo "$(date) - Password not set"
    fi
    echo "$(date) - Sleeping"
    sleep "${SLEEP_TIME}"
done