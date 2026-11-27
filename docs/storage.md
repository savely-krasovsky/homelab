# Storage

Prepare the encrypted `spool` pool, zvol and datasets on PVE before applying
OpenTofu. Fedora CoreOS expects `spool/docker` to already contain `vg0/lv0`
formatted as XFS. The zvol is 200 GiB and the logical volume is 100 GiB.
[VM attachments](../fcos.tf) and [directory mappings](../storage.tf) use this
existing storage. Keep the zvol's device path absolute and `datastore_id` empty
so it survives VM replacement.

## Boot and unlock

PVE imports the pool from `/etc/zfs/zpool.cache`, loads the key, and mounts the
shared datasets before guest autostart. All children use `encryptionroot=spool`
and unlock together using `/etc/zfs/keys/spool.key`.
ZED maintains `/etc/zfs/zfs-list.cache/spool` for `zfs-mount-generator`.
The pool root uses `mountpoint=/mnt/spool` and `canmount=off`.

The key directory/file are `root:root`, modes 0700/0600. Keep a separate key copy outside Git.
The key is on unencrypted `rpool`, so encryption does not protect against theft of the whole server.

Set the boot dependencies on all four shares when configuring the host.

```sh
for dataset in media personal observability random; do
  zfs set canmount=on \
    org.openzfs.systemd:before=pve-guests.service \
    org.openzfs.systemd:required-by=pve-guests.service "spool/$dataset"
done
```

After changing properties, let ZED update the cache, then run `systemctl daemon-reload`.
A mount failure blocks `pve-guests.service` autostart. Manual VM starts bypass this dependency.

## Fedora CoreOS

[Butane](../butane/fcos.yml.tftpl) activates the existing `vg0` by PV UUID and
waits for all mounts before starting the application user manager. VirtIO-FS
shares already have the `container_file_t` context. On local XFS paths, use
`Z` for private container bind mounts and `z` for shared ones.

## Checks and recovery

Run these checks on PVE.

```sh
zpool status spool
zfs get keystatus,keylocation spool
zfs list -r -t filesystem,volume -o name,mounted,mountpoint,canmount spool
systemctl status zfs-load-key@spool.service
systemctl show pve-guests.service -p Requires -p After
```

After fixing an unlock or mount error, start the shared mounts.

```sh
systemctl start mnt-spool-media.mount mnt-spool-personal.mount mnt-spool-observability.mount mnt-spool-random.mount
```

Before manually starting Fedora CoreOS, verify the four host mounts with `findmnt -M`
and check that `/dev/zvol/spool/docker` exists.

## Backups

The [PVE jobs](../backups.tf) back up the application disk to PBS. The
[file-backup hook](../pve/file-backup.sh.tftpl) backs up `personal` and
`observability` separately as `host/homelab-files` using the same PBS storage
credentials and keys. PBS prune jobs manage file archive retention. See PVE Tasks
for job and hook output.

VM backups omit the OS disk. File backups omit
`media`, `random` and the derived data listed in the hook. Regenerate derived
data after restoring. File snapshots are taken independently of application
writes and the VM backup. Check application consistency after a restore.
Restore verification is manual.

After a power loss, check for leftover `@pbs-files-*` snapshots.
