# Experimental Homelab

- Uses immutable, atomic OS provisioned on Proxmox VE node as a base.
- Uses rootless Podman instead of rootful Docker.
- Uses Quadlets systemd-like containers instead of Docker Compose.
- VM can be fully removed and re-provisioned within 3 minutes, including container autostart.
- Provisioning of everything is done using Terraform/OpenTofu.
- Secrets are provided using Bitwarden Secrets Manager.
- Source IP is preserved
  using [systemd socket activation](https://github.com/eriksjolund/podman-networking-docs?tab=readme-ov-file#socket-activation-systemd-user-service)
  mechanism.
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

| Name                                    | Description                                | Pod |
|-----------------------------------------|--------------------------------------------|-----|
| Actual Budget                           | Budgeting App                              |     |
| Bluesky PDS                             | ATProto Personal Data Server               |     |
| Element Web                             | Element Web Client                         |     |
| Element Call                            | Element Call Client                        |     |
| Glance                                  | Homelab Dashboard                          |     |
| Grafana                                 | Data-visualization Platform                |     |
| Grafana Alloy                           | OpenTelemetry Collector                    |     |
| Davmail                                 | Exchange to IMAP/SMTP Gateway              |     |
| Karakeep                                | Bookmark App                               | ☑️  |
| Immich                                  | Image & Video Management                   | ☑️  |
| Matrix                                  | Matrix Homeserver                          | ☑️  |
| MatrixRTC                               | Matrix Realtime Stack                      | ☑️  |
| Miniflux                                | RSS Reader                                 | ☑️  |
| OAuth2 Proxy                            | Identity-Aware Proxy                       |     |
| OpenCloud                               | File Management and Collaboration platform | ☑️  |
| Open WebUI                              | Chatbot UI                                 | ☑️  |
| Outline                                 | Personal Knowledge Base                    | ☑️  |
| Plex                                    | Personal Media Server                      |     |
| Pocket ID                               | Single Sign-on Portal                      |     |
| Podman Exporter                         | Podman Prometheus Metrics Exporter         |     |
| rmqtt                                   | MQTT Broker Server                         |     |
| qBittorrent                             | BitTorrent Client                          |     |
| SimpleX                                 | Secure Messaging App                       | ☑️  |
| Tangled Knot                            | Git Platform based on ATProto              |     |
| Telegraf                                | Only for MQTT to OpenTelemetry conversion  |     |
| Traefik                                 | Application Proxy                          |     |
| Gatus                                   | Uptime Monitoring[^1]                      |     |
| VictoriaMetrics / VictoriaLogs / vmauth | Metrics and Logs Storage                   | ☑️  |

[^1]: It lives outside Homeleb.

## Caveats

This is not a ready-to-use configuration that you can just apply. It requires initialized state.
You can apply it, then go to Pocket ID, generate OAuth2 Client IDs, and paste them into container templates.
Technically, it's possible to make it as generic as possible, but I don't think anyone wants to copy my setup entirely.
I see this more as a template for your own setups.

## Future plans

- [x] Move Traefik, Grafana Alloy and other configs to the repository.
- [ ] Consider switching to Flatcar Linux. Personally I like it more, but in the current version they didn't ship
  `i915` driver, which is a dealbreaker for me. However,
  it's [already merged](https://github.com/flatcar/scripts/pull/2349)
  and will soon be available in the Alpha channel.
- [x] Monitor uptime and setup alerts with Uptime Kuma.
- [ ] Harden network setup; for now it's pretty permissive.
- [ ] Integrate `hashicorp/assert` support.
