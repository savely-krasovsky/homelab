# Experimental Homelab

- Uses immutable, atomic OS provisioned on Proxmox VE node as a base.
- Uses rootless Podman instead of rootful Docker.
- Uses Quadlets systemd-like containers instead of Docker Compose.
- VM can be fully removed and re-provisioned within 3 minutes, including container autostart.
- Provisioning of everything is done using Terraform/OpenTofu.
- Secrets are provided using Bitwarden Secrets Manager.
- Source IP is preserved using [systemd socket activation](https://github.com/eriksjolund/podman-networking-docs?tab=readme-ov-file#socket-activation-systemd-user-service) mechanism.
- Native network performance due to the reason above.
- Stores Podman and application data on dedicated iSCSI disk.
- Stores media and downloads on NFS share.
- SELinux support.

## Caveats

This is not a ready-to-use configuration that you can just apply. It requires initialized state.
You can apply it, then go to Pocket ID, generate OAuth2 Client IDs, and paste them into container templates.
Technically, it's possible to make it as generic as possible, but I don't think anyone wants to copy my setup entirely.
I see this more as a template for your own setups.

## Future plans

I would like to switch to Flatcar Linux, but for now it doesn't include the `i915` kernel driver,
which is a dealbreaker for me. However, it's [already merged](https://github.com/flatcar/scripts/pull/2349)
and will soon be available in the Alpha channel.