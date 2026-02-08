#!/bin/bash
set -e

BWS_ACCESS_TOKEN=$(systemd-creds --system cat bws-access-token)

podman run --rm -v /var/home/core:/home/app --user 1000:1000 --uidmap +1000:@1000:1 --security-opt=label=disable \
  docker.io/bitwarden/bws secret get --color=no --access-token="${BWS_ACCESS_TOKEN}" "$1" | jq -r .value | head -c -1