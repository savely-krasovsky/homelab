# Host-owned ZFS storage

PVE owns `spool`; guests do not. The pool appears under **Node → Disks → ZFS**,
not as a VM-image allocation backend under Datacenter → Storage.

| Data | PVE attachment | FCOS mount | VM backup |
| --- | --- | --- | --- |
| `spool/docker`, 200 GiB zvol | `scsi1`, `/dev/zvol/spool/docker` | `vg0/lv0`, 100 GiB XFS, `/var/mnt/docker` | `backup=1` |
| `spool/media` | `homelab-media`, `virtiofs0` | `/var/mnt/media` | No |
| `spool/personal` | `homelab-personal`, `virtiofs1` | `/var/mnt/personal` | No |
| `spool/observability` | `homelab-observability`, `virtiofs2` | `/var/mnt/observability` | No |
| `spool/random` | `homelab-random`, `virtiofs3` | `/var/mnt/random` | No |

Directory Mappings are under Datacenter → Resource Mappings → Directory;
attachments are under VM → Hardware. Node → Disks → Directory is unrelated.

The zvol uses an absolute device path and empty `datastore_id`, not a VM-owned
`vm-100-disk-*` volume. PVE skips absolute-path disks on VM removal; the provider
marks passthrough experimental. Do not change disk ownership casually.
Never pass controller `0000:00:17.0` to a guest while PVE owns the pool.

## Host boot

This is host OpenZFS configuration, **outside Terraform and the PVE GUI**.
It uses stock import, mount-generator and ZED services; no custom unlock, NFS or SMB service.

- Pool cache: `/etc/zfs/zpool.cache`; import through `zfs-import-cache.service`.
- `spool`: `mountpoint=/mnt/spool`, `canmount=off`, `keylocation=file:///etc/zfs/keys/spool.key`.
- Key directory/file: `root:root`, modes 0700/0600. Keep a separate secure key copy;
  never put it in Git, Ignition or Terraform state.
- Dataset cache: `/etc/zfs/zfs-list.cache/spool`, maintained by ZED. It stores the key path, not the key.
- The four shared datasets set `org.openzfs.systemd:before=pve-guests.service`
  and `org.openzfs.systemd:required-by=pve-guests.service`.
- `spool/random` must use `canmount=on` and the same guest-start dependencies as the other shared datasets. `ix-apps` uses `canmount=noauto`; TrueNAS `.system` mounts remain legacy.

The generator creates `zfs-load-key@spool.service` and the four `mnt-spool-*.mount`
units. Import/unlock/mount failure blocks **general PVE guest autostart**, not just
FCOS. Manual `qm start` bypasses this dependency: check storage first.
The key is on unencrypted `rpool`; this permits unattended boot but does not
protect against theft of the whole server. A full PVE cold boot is not yet verified.

For `spool/random`, configure the host mount before starting FCOS:

```sh
zfs set canmount=on spool/random
zfs set org.openzfs.systemd:before=pve-guests.service spool/random
zfs set org.openzfs.systemd:required-by=pve-guests.service spool/random
systemctl daemon-reload
systemctl start mnt-spool-random.mount
```

## FCOS

[Butane](../butane/fcos.yml.tftpl) activates only the existing `vg0` identified by
PV UUID, mounts its XFS LV and the four VirtIO-FS shares, and requires all five
mounts before starting `user@1000.service`. It creates no PV/VG/LV.
VirtIO-FS exposes ACLs/xattrs with `container_file_t`; SELinux stays enforcing.
These shares use a fixed SELinux mount context, so container bind mounts need
no `z`/`Z` relabeling. Local XFS application data and configuration files still
use `Z` for private paths or `z` for shared paths. Bind mounts are read-write
by default; only read-only consumers specify `ro`.
Ignition changes apply on first boot, not by uploading a new file to a running VM.

Stash reads `/var/mnt/random` as `/data`; qBittorrent can write to it as
`/random`. The dataset must allow the application user (UID/GID 1000) to
traverse, read and write files. Stash state lives under
`/var/mnt/docker/app_data/stash`. Its web UI uses `stash.${base_domain}`
behind the existing OAuth2 Proxy; enable Stash authentication to restrict
access further than the shared proxy login.

## Checks and recovery

Read-only checks on PVE:

```sh
zpool status spool
zfs get keystatus,keylocation spool
zfs get mounted,mountpoint spool/media spool/personal spool/observability spool/random
systemctl status zfs-load-key@spool.service
systemctl status mnt-spool-media.mount mnt-spool-personal.mount mnt-spool-observability.mount mnt-spool-random.mount
systemctl show pve-guests.service -p Requires -p After
```

After fixing an unlock/mount error, retry the normal path:

```sh
systemctl start mnt-spool-media.mount mnt-spool-personal.mount mnt-spool-observability.mount mnt-spool-random.mount
```

Before starting FCOS, check each host path with `findmnt -M` and verify that
`/dev/zvol/spool/docker` exists. Do not force-import from another owner, change
pool features or format disks to resolve an unlock failure.

Saved configuration: `/root/homelab-storage-trial.L1wAif` and
`/root/homelab-storage-permanent.ZDWhJj` on PVE. Data snapshots named
`@homelab-pre-direct-20260917` are same-pool checkpoints, not independent backups.

Changing pool ownership requires stopping consumers, preventing PVE reimport/autostart,
unmounting and exporting `spool` before another host or guest imports it.
**Do not roll back data snapshots merely to change ownership**; that would discard
newer application writes.

## Backup limits

VirtIO-FS contents need separate file-backup jobs. `backup=1` on the application
zvol does not establish a tested restore path. Application-disk backups use PBS;
Butane no longer provisions restic jobs. Existing FCOS hosts need their old backup
and prune timers disabled separately. TrueNAS SMB and photo cloud-backup jobs are
not migrated; automated restore tests are not configured.

### File backups to PBS

[`pve/file-backup.sh`](../pve/file-backup.sh) runs on PVE as root. It snapshots
`spool/personal` and `spool/observability`, sends both archives to the existing
`storj` and `backblaze` PBS datastores, then removes its snapshots. Both destinations
are attempted; any failure makes the service fail. It reuses PVE's existing
`/etc/pve/priv/storage/pbs-{storj,backblaze}.{pw,enc}` credentials and encryption keys.
No secrets belong in this repository.

Exclusions are explicit paths relative to each archive root: Immich `thumbs` and
`encoded-video` contents (keeping `.immich` markers), OpenCloud `thumbnails` and
`search`, and VictoriaMetrics `metrics/cache` and `metrics/tmp`. Originals, Immich
`profile` and database dumps, OpenCloud storage/metadata, and observability history
remain included. After restore, regenerate Immich thumbnails/transcodes and rebuild
the OpenCloud search index. See [Immich backup exclusions](https://docs.immich.app/guides/template-backup-script/)
and [OpenCloud backup guidance](https://github.com/opencloud-eu/docs/blob/main/docs/admin/maintenance/backup.md).

These are filesystem snapshots, not application-coordinated backups. They are not
atomic with the separate VM backup containing application databases. Restoring
Victoria data or applications that link database records to personal files needs
an application-specific recovery check.

Copy the three files in `pve/` to PVE, then install from that directory:

```sh
install -m 0755 file-backup.sh /usr/local/sbin/homelab-file-backup
install -m 0644 homelab-file-backup.{service,timer} /etc/systemd/system/
systemctl daemon-reload
systemctl start homelab-file-backup.service
journalctl -u homelab-file-backup.service -e
# After checking the first backup and restoring a sample file:
systemctl enable --now homelab-file-backup.timer
```

The timer runs at 02:00 PVE local time and catches up after downtime. PBS displays
the backups as `host/homelab-files`, with `personal.pxar` and `observability.pxar` archives;
retention is managed by the PBS datastore prune jobs. First upload includes all
files; later runs reuse unchanged data using metadata change detection.
The script does not prune backups or change existing VM backup schedules.
After a power loss, check for leftover `@pbs-files-*` snapshots on these two datasets.

References: [OpenZFS mount generator](https://openzfs.github.io/openzfs-docs/man/master/8/zfs-mount-generator.8.html),
[key loading](https://openzfs.github.io/openzfs-docs/man/master/8/zfs-load-key.8.html),
[Proxmox VirtIO-FS](https://github.com/proxmox/pve-docs/blob/master/qm.adoc#virtiofs),
[provider passthrough](https://github.com/bpg/terraform-provider-proxmox/blob/v0.113.1/docs/resources/virtual_environment_vm.md#example-disk-pass-through),
[PBS file backups](https://pbs.proxmox.com/docs/backup-client.html).
