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

I also have some observability:

  - Storage: VictoriaMetrics and VictoriaLogs.
  - Scrapping and writing: Grafana Alloy.
  - Visualization: Grafana.
  - Traces are not supported for now.

## Current services

| Name                                    | Description                  | Pod |
|-----------------------------------------|------------------------------|-----|
| Actual Budget                           | Budgeting App                |     |
| Bluesky PDS                             | ATProto Personal Data Server |     |
| Glance                                  | Homelab Dashboard            |     |
| Grafana                                 | Data-visualization Platform  |     |
| Grafana Alloy                           | OpenTelemetry Collector      |     |
| Hoarder                                 | Bookmark App                 | ☑️  |
| Immich                                  | Image & Video Management     | ☑️  |
| Miniflux                                | RSS Reader                   | ☑️  |
| OAuth2 Proxy                            | Identity-Aware Proxy         |     |
| Open WebUI                              | Chatbot UI                   |     |
| Outline                                 | Personal Knowledge Base      | ☑️  |
| Plex                                    | Personal Media Server        |     |
| Pocket ID                               | Single Sign-on Portal        |     |
| qBittorrent                             | BitTorrent Client            |     |
| Traefik                                 | Application Proxy            |     |
| VictoriaMetrics / VictoriaLogs / vmauth | Metrics and Logs Storage     | ☑️  |

## Caveats

This is not a ready-to-use configuration that you can just apply. It requires additional configuration files
and initialized state. You can apply it, write those configs, then go to Pocket ID, generate OAuth2 Client IDs,
and paste them into container templates. Technically, it's possible to make it as generic as possible,
but I don't think anyone wants to copy my setup entirely. I see this more as a template for your own setups.

## Future plans

I would like to switch to Flatcar Linux, but for now it doesn't include the `i915` kernel driver,
which is a dealbreaker for me. However, it's [already merged](https://github.com/flatcar/scripts/pull/2349)
and will soon be available in the Alpha channel.

Also, I want to move my Traefik, Grafana Alloy and Victoria vmauth configurations to this repo
at some point, but I didn't figure out how to do it properly now.

And finally I want to harden my network setup, since for now it's pretty permissive.
