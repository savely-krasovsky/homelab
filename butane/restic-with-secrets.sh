#!/bin/bash
# Installed by Ignition as root; invoked by the system backup and prune units.
set -euo pipefail

case "${1-}" in
    backblaze|storj) backend=$1; shift ;;
    *) echo 'Expected backup backend: backblaze or storj' >&2; exit 2 ;;
esac

runtime_dir=/run/user/$(id -u homelab)
secret() {
    runuser -u homelab -- env XDG_RUNTIME_DIR="$runtime_dir" \
        podman secret inspect --showsecret --format '{{.SecretData}}' "$1"
}

# Separate assignments preserve failures; export VAR=$(command) would hide them.
RESTIC_PASSWORD=$(secret restic-password)
export RESTIC_PASSWORD
unset RESTIC_PASSWORD_FILE RESTIC_PASSWORD_COMMAND

case "$backend" in
    backblaze)
        B2_ACCOUNT_ID=$(secret restic-b2-account-id)
        B2_ACCOUNT_KEY=$(secret restic-b2-account-key)
        export B2_ACCOUNT_ID B2_ACCOUNT_KEY
        ;;
    storj)
        AWS_ACCESS_KEY_ID=$(secret restic-aws-access-key-id)
        AWS_SECRET_ACCESS_KEY=$(secret restic-aws-secret-access-key)
        export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
        ;;
esac

exec restic "$@"
