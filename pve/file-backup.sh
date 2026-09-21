#!/usr/bin/env bash
set -euo pipefail

stores=(storj backblaze)
if (( $# > 0 )); then
    if (( $# != 1 )) || [[ $1 != storj && $1 != backblaze ]]; then
        echo "Usage: $0 [storj|backblaze]" >&2
        exit 2
    fi
    stores=("$1")
fi

# Run on PVE as root. Reuse the credentials of its existing PBS storages.
exec 9>/run/lock/homelab-file-backup.lock
flock -n 9

datasets=(spool/personal spool/observability)
snapshot="pbs-files-$(date -u +%Y%m%dT%H%M%SZ)"
snapshots=()
archives=()

for dataset in "${datasets[@]}"; do
    [[ $(zfs get -H -o value mounted "$dataset") == yes ]]
    mountpoint=$(zfs get -H -o value mountpoint "$dataset")
    snapshots+=("$dataset@$snapshot")
    archives+=("${dataset##*/}.pxar:$mountpoint/.zfs/snapshot/$snapshot")
done

zfs snapshot "${snapshots[@]}"
cleanup() {
    local result=$?
    for saved_snapshot in "${snapshots[@]}"; do
        zfs destroy "$saved_snapshot" || result=1
    done
    exit "$result"
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

# Attempt both destinations even when one fails; report any failure to systemd.
result=0
for store in "${stores[@]}"; do
    echo "Backing up $snapshot to $store"
    if ! PBS_PASSWORD_FILE="/etc/pve/priv/storage/pbs-$store.pw" \
        proxmox-backup-client backup "${archives[@]}" \
            --repository "pve@pbs!pve@pbs.lan.krasovs.ky:$store" \
            --keyfile "/etc/pve/priv/storage/pbs-$store.enc" \
            --crypt-mode encrypt \
            --backup-type host --backup-id homelab-files \
            --exclude '/immich/thumbs/*' \
            --exclude '!/immich/thumbs/.immich' \
            --exclude '/immich/encoded-video/*' \
            --exclude '!/immich/encoded-video/.immich' \
            --exclude '/opencloud/thumbnails/' \
            --exclude '/opencloud/search/' \
            --exclude '/metrics/cache/' \
            --exclude '/metrics/tmp/' \
            --change-detection-mode metadata; then
        result=1
    fi
done
exit "$result"
