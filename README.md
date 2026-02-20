# Experimental Homelab

- Uses immutable, atomic Fedora CoreOS provisioned on a Proxmox VE node as a base.
- Uses rootless Podman instead of rootful Docker.
- Uses Quadlet systemd-like containers instead of Docker Compose.
- VM can be fully removed and re-provisioned in a few minutes, including container autostart.
- Provisioning is done with OpenTofu/Terraform.
- Configs are rendered from templates and synced automatically after changes.
- Secrets are provided using Bitwarden Secrets Manager.
- Bitwarden token is injected into VM credentials and then mapped to Podman/system credentials during bootstrap.
- Source IP is preserved using
  [systemd socket activation](https://github.com/eriksjolund/podman-networking-docs?tab=readme-ov-file#socket-activation-systemd-user-service)
  with Traefik.
- Native network performance due to the reason above.
- Podman and application data are stored on a dedicated iSCSI-backed LVM disk.
- Media, personal files, and observability data are stored on NFS shares.
- Daily restic backups are done from LVM snapshots to Backblaze B2 and Storj.
- Uses per-stack Podman networks plus a shared reverse-proxy network.
- Container-to-container traffic stays on-host inside Podman networks,
  while shared domain names are still used via Traefik `NetworkAlias`.
- Uses nftables default-deny firewall policy.
- SELinux support (including explicit context fixes where needed).

I also have some observability:

- Storage: VictoriaMetrics, VictoriaLogs, and VictoriaTraces.
- Collection and routing: Grafana Alloy (Prometheus/Loki/OTLP) and Telegraf for MQTT -> OTLP.
- Visualization: Grafana.
- Traefik itself exports logs/metrics/traces via OTLP to Alloy.

## Current services

| Name                                                            | Description                                       | Pod |
|-----------------------------------------------------------------|---------------------------------------------------|-----|
| Actual Budget (`actual-budget`)                                 | Budgeting App                                     |     |
| Anubis (`anubis`)                                               | Anti-bot ForwardAuth gateway                      |     |
| Bluesky PDS (`bluesky-pds`)                                     | ATProto Personal Data Server                      |     |
| CrowdSec (`crowdsec-security-engine`)                           | Advanced Fail2ban                                 | ☑️  |
| CrowdSec Web UI (`crowdsec-web-ui`)                             | CrowdSec web interface                            | ☑️  |
| DavMail (`davmail`)                                             | Exchange Gateway                                  |     |
| Element Admin (`element-admin`)                                 | Element Admin Panel                               |     |
| Element Call (`element-call`)                                   | Element Call Client                               |     |
| Element Web (`element-web`)                                     | Matrix Web Client                                 |     |
| Forward Info Bot (`forward-info-bot`)                           | Telegram utility bot                              |     |
| Glance (`glance`)                                               | Homelab Dashboard                                 |     |
| Grafana Alloy (`grafana-alloy`)                                 | OpenTelemetry Collector                           |     |
| Grafana (`grafana`)                                             | Data-visualization Platform                       |     |
| Immich ML (`immich-machine-learning`)                           | Immich machine-learning worker                    | ☑️  |
| Immich (`immich-server`)                                        | Image & Video Management                          | ☑️  |
| Karakeep Chrome (`karakeep-chrome`)                             | Browser worker for archiving                      | ☑️  |
| Karakeep Meilisearch (`karakeep-meilisearch`)                   | Search index                                      | ☑️  |
| Karakeep (`karakeep-server`)                                    | Bookmark App                                      | ☑️  |
| Masked Email Bot (`masked-email-bot`)                           | Telegram utility bot                              |     |
| MatrixRTC JWT (`matrix-rtc-jwt`)                                | LiveKit JWT service                               | ☑️  |
| MatrixRTC SFU (`matrix-rtc-sfu`)                                | Matrix Realtime Stack                             | ☑️  |
| Matrix Authentication Service (`matrix-authentication-service`) | Matrix auth service                               | ☑️  |
| Matrix Synapse (`matrix-synapse`)                               | Matrix Homeserver                                 | ☑️  |
| Miniflux (`miniflux-server`)                                    | RSS Reader                                        | ☑️  |
| OAuth2 Proxy (`oauth2-proxy-server`)                            | Identity-Aware Proxy                              | ☑️  |
| Open WebUI (`open-webui`)                                       | Chatbot UI                                        | ☑️  |
| OpenCloud (`opencloud-server`)                                  | File Management and Collaboration Platform        | ☑️  |
| OpenCloud Collabora (`opencloud-collabora`)                     | Office editing backend                            | ☑️  |
| OpenCloud Collaboration (`opencloud-collaboration`)             | Realtime collaboration service                    | ☑️  |
| Opengist (`opengist`)                                           | Self-hosted Pastebin powered by Git               |     |
| Outline (`outline-server`)                                      | Personal Knowledge Base                           | ☑️  |
| Plex (`plex`)                                                   | Personal Media Server                             |     |
| Pocket ID (`pocket-id`)                                         | Single Sign-on Portal                             |     |
| Podman Exporter (`prometheus-podman-exporter`)                  | Podman Prometheus Metrics Exporter                |     |
| qBittorrent (`qbittorrent`)                                     | BitTorrent Client                                 |     |
| Remnawave Panel (`remnawave-panel`)                             | Censorship Circumvention Management Platform      | ☑️  |
| Remnawave Subscription Page (`remnawave-subscription-page`)     | Public subscription page                          | ☑️  |
| Remnawave Node 2 (`remnawave-node-2`)                           | Proxy access node                                 |     |
| Remnawave Node (`remnawave-node`)                               | Proxy access node                                 |     |
| RMQTT (`rmqtt`)                                                 | MQTT Broker Server                                |     |
| Static Web Server (`static-web-server`)                         | Static files host                                 |     |
| Step CA (`step-ca`)                                             | Smallstep-based Homelab CA infrastructure         |     |
| Tangled Knot (`tangled`)                                        | Git Platform based on ATProto                     |     |
| Telegraf (`telegraf`)                                           | MQTT to OpenTelemetry conversion                  |     |
| Traefik (`traefik`)                                             | Application Proxy                                 |     |
| VictoriaLogs (`victoria-logs`)                                  | Logs Storage                                      | ☑️  |
| VictoriaMetrics (`victoria-metrics`)                            | Metrics Storage                                   | ☑️  |
| VictoriaTraces (`victoria-traces`)                              | Tracing Storage                                   | ☑️  |
| vmauth (`victoria-vmauth`)                                      | Authorization module for VictoriaMetrics products | ☑️  |
| Gatus                                                           | Uptime Monitoring[^2]                             |     |

## Caveats

This is not a ready-to-use configuration that you can just apply.
It requires initialized state and personal values (DNS, Proxmox, TrueNAS, Bitwarden secret IDs, Pocket ID clients,
etc.).
You can adapt it, but copying it as-is is not realistic.
I see this repository more as a template for your own setup.

## Future plans

- [x] Move Traefik, Grafana Alloy and other configs to the repository.
- [ ] Consider switching to Flatcar Linux. I still like it more, but missing pieces were a blocker.
- [x] Monitor uptime and setup alerts with an external monitor[^1].
- [ ] Harden network setup; some parts are still permissive.
- [ ] Integrate `hashicorp/assert` support.

[^1]: It lives outside this repository.
[^2]: It lives outside this homelab host.
