# Experimental Homelab

- Uses immutable, atomic OS provisioned on Proxmox VE node as base.
- Uses rootless Podman instead of rootful Docker.
- Uses Quadlets systemd-like containers instead of Docker Compose.
- VM can be fully removed and re-provisioned again within 3 minutes, including containers autostart.
- Provisioning of everything done using Terraform/OpenTofu.
- Secrets provided using Bitwarden Secrets Manager.
- Source IP is preserved using [systemd socket activation](https://github.com/eriksjolund/podman-networking-docs?tab=readme-ov-file#socket-activation-systemd-user-service) mechanism.
- Native network performance for the reason above.
- Stores Podman and applications data on dedicated iSCSI disk.
- Stores media and downloads on NFS share.
- SELinux support.

## Future plans

I would like to switch to Flatcar Linux, but for now it doesn't include `i915` kernel driver
which is a dealbreaker for me now. But it's [already merged](https://github.com/flatcar/scripts/pull/2349)
and will be soon available in Alpha channel.