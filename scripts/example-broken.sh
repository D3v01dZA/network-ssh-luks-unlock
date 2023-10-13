#!/usr/bin/env bash

./unlock-script.sh --address 192.168.97.128 --port 2223 --user root --identity .ssh/id_ed25519 --password $(cat ssh/password-file)
