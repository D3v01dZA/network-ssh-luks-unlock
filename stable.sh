#!/bin/bash

set -Eeuo pipefail

trap fail ERR

fail() {
    echo "Failed"
}

#docker buildx create --name multiarch
docker buildx use multiarch
docker buildx build -f Dockerfile.server . --platform linux/arm/v7 --platform linux/arm64 --platform linux/amd64 --tag d3v01d/network-ssh-luks-unlock-server:stable --push
docker buildx build -f Dockerfile.replicator . --platform linux/arm/v7 --platform linux/arm64 --platform linux/amd64 --tag d3v01d/network-ssh-luks-unlock-replicator:stable --push
