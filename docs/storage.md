# Storage

PVE owns the encrypted `spool` pool; FCOS receives its zvol and VirtIO-FS shares.
Host storage configuration is managed outside OpenTofu.

| Data | PVE attachment | FCOS mount | VM backup |
| --- | --- | --- | --- |
| `spool/docker`, 200 GiB zvol | `scsi1`, `/dev/zvol/spool/docker` | `vg0/lv0`, 100 GiB XFS, `/var/mnt/docker` | `backup=1` |
| `spool/media` | `homelab-media`, `virtiofs0` | `/var/mnt/media` | No |
| `spool/personal` | `homelab-personal`, `virtiofs1` | `/var/mnt/personal` | No |
| `spool/observability` | `homelab-observability`, `virtiofs2` | `/var/mnt/observability` | No |
| `spool/random` | `homelab-random`, `virtiofs3` | `/var/mnt/random` | No |

PVE GUI: pool under **Node → Disks → ZFS**, directory mappings under
**Datacenter → Resource Mappings → Directory**, attachments under **VM → Hardware**.
The zvol uses an absolute device path and empty `datastore_id`; PVE does not delete it with the VM.

## Boot and unlock

Boot order: pool import → key loading → shared mounts → guest autostart.

- `zfs-import-cache.service` imports pools from `/etc/zfs/zpool.cache`.
- `zfs-load-key@spool.service` runs `zfs load-key spool`, reading `/etc/zfs/keys/spool.key`.
  All children, including `docker`, use `encryptionroot=spool` and unlock together.
- ZED maintains `/etc/zfs/zfs-list.cache/spool`; `zfs-mount-generator` uses it to
  generate the key-loading service and four `mnt-spool-*.mount` units.
- `spool` has `mountpoint=/mnt/spool`, `canmount=off`; the four shared datasets use `canmount=on`.

The key directory/file are `root:root`, modes 0700/0600. Keep a separate key copy outside Git.
The key is on unencrypted `rpool`, so encryption does not protect against theft of the whole server.

All four shares have the same boot dependencies, already configured:

```sh
for dataset in media personal observability random; do
  zfs set canmount=on \
    org.openzfs.systemd:before=pve-guests.service \
    org.openzfs.systemd:required-by=pve-guests.service "spool/$dataset"
done
```

This is a homelab policy using [OpenZFS systemd properties](https://openzfs.github.io/openzfs-docs/man/master/8/zfs-mount-generator.8.html#properties).
A mount failure blocks the common `pve-guests.service` autostart. Manual VM starts bypass this dependency.
After changing properties, let ZED update the cache, then run `systemctl daemon-reload`.

## FCOS

[Butane](../butane/fcos.yml.tftpl) activates the existing `vg0` by PV UUID and
requires all five mounts before starting `user@1000.service`; it creates no PV/VG/LV.
VirtIO-FS shares use `container_file_t`, so container bind mounts need no `z`/`Z`.
Local XFS data still needs `Z` for private paths or `z` for shared paths.

## Checks and recovery

On PVE:

```sh
zpool status spool
zfs get keystatus,keylocation spool
zfs list -r -t filesystem,volume -o name,mounted,mountpoint,canmount spool
systemctl status zfs-load-key@spool.service
systemctl show pve-guests.service -p Requires -p After
```

After fixing an unlock or mount error:

```sh
systemctl start mnt-spool-media.mount mnt-spool-personal.mount mnt-spool-observability.mount mnt-spool-random.mount
```

Before manually starting FCOS, verify the four host mounts with `findmnt -M`
and check that `/dev/zvol/spool/docker` exists.

## Backups

[`backups.tf`](../backups.tf) manages two jobs under **Datacenter → Backup**:

| Job | PVE local time | PBS storage |
| --- | --- | --- |
| `fcos-storj` | 06:00 | `pbs-storj` |
| `fcos-backblaze` | 07:00 | `pbs-backblaze` |

Each job backs up the FCOS application disk, then its `job-end` hook snapshots
`personal` and `observability`, uploads them to the same PBS destination and removes
the snapshots. OpenTofu renders one executable [snippet](../pve/file-backup.sh.tftpl)
per cloud under `/var/lib/vz/snippets/`. PVE Tasks includes the hook output and failures.
Jobs share PVE's backup lock; overlapping runs wait subject to PVE's lock timeout.

The hooks reuse `/etc/pve/priv/storage/pbs-{storj,backblaze}.{pw,enc}` credentials
and keys. File archives remain separate as `host/homelab-files` in PBS;
PBS prune jobs manage their retention. `media` and `random` are not included.

Excluded data: Immich thumbnails/transcodes (keeping `.immich` markers), OpenCloud
thumbnails/search index, and VictoriaMetrics cache/tmp. Regenerate derived data after restore.
File snapshots are not coordinated with applications or the separate VM backup;
restores need an application-level consistency check. Automated restore tests are not configured.

After a power loss, check for leftover `@pbs-files-*` snapshots.
