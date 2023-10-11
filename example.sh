#!/usr/bin/env bash

./unlock-script.sh --address 192.168.97.128 --port 2222 --user root --identity ssh/unlock_key --password $(cat ssh/password-file)
