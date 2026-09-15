# Experimental Homelab

Configuration and deployment scripts for my personal homelab.

- Uses immutable, atomic Fedora CoreOS provisioned on a Proxmox VE node as a base.
- Uses rootless Podman instead of rootful Docker.
- Uses Quadlet systemd-like containers instead of Docker Compose.
- VM can be fully removed and re-provisioned in a few minutes, including container autostart.
- Provisioning is done with OpenTofu/Terraform.
- Configs are rendered from templates and deployed over SSH by my
  [deployment provider](https://github.com/savely-krasovsky/terraform-provider-quadlet).
- Image bumps arrive as Renovate PRs; `AutoUpdate=registry` is kept only on rolling tags,
  whose patch releases Renovate cannot see.
- Secrets are provided using Bitwarden Secrets Manager.
- Ephemeral Bitwarden values are installed as Podman secrets, one resource each;
  bump `secret_versions` after a rotation; deployment triggers activate container consumers.
- System restic backup and prune jobs read their five secrets from core's Podman store
  at each invocation through [the restic wrapper](butane/restic-with-secrets.sh).
  Secret values stay out of Ignition and Terraform state.
- Source IP is preserved using
  [systemd socket activation](https://github.com/eriksjolund/podman-networking-docs?tab=readme-ov-file#socket-activation-systemd-user-service)
  with Traefik.
- Native network performance due to the reason above.
- Podman and application data are stored on a dedicated iSCSI-backed LVM disk.
- Media, personal files, and observability data are stored on NFS shares.
- Daily restic backups are done from LVM snapshots to Backblaze B2 and Storj,
  skipping the paths listed in `/etc/restic/excludes.txt` and pruned weekly
  down to 14 daily, 8 weekly and 12 monthly snapshots.
- Uses per-application Podman networks plus a shared reverse-proxy network.
- Container-to-container traffic stays on-host inside Podman networks,
  while shared domain names are still used via Traefik `NetworkAlias`.
- Uses nftables default-deny firewall policy.
- SELinux support (including explicit context fixes where needed).

I also have some observability:

- Storage: VictoriaMetrics, VictoriaLogs, and VictoriaTraces.
- Collection and routing: Grafana Alloy (Prometheus/Loki/OTLP) and Telegraf for MQTT -> OTLP.
- Containers opt into metrics scraping with `alloy.metrics.*` Quadlet labels, discovered by Alloy over the Podman socket.
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
| Prusa Exporter (`prusa-exporter`)                               | Prusa 3D Printer Prometheus Metrics Exporter      |     |
| qBittorrent (`qbittorrent`)                                     | BitTorrent Client                                 |     |
| Remnawave Panel (`remnawave-panel`)                             | Censorship Circumvention Management Platform      | ☑️  |
| Remnawave Subscription Page (`remnawave-subscription-page`)     | Public subscription page                          | ☑️  |
| Remnawave Node VLESS XHTTP (`remnawave-node-vless-xhttp`)       | Proxy access node                                 |     |
| Remnawave Node VLESS REALITY (`remnawave-node-vless-reality`)   | Proxy access node                                 |     |
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
| Gatus                                                           | Uptime Monitoring[^gatus]                         |     |

## Deployment

[deployment.tf](deployment.tf) renders files from [configs](configs) and groups
them into applications. Each application owns its configuration, containers,
networks and volumes. The resources in [fcos.tf](fcos.tf) install its files and
activate its units when the files, secret revisions or activation settings change.

The `applications` map defines each deployment:

| Field | Purpose |
| --- | --- |
| `paths` | Files or directories under `configs`, including the selected units' drop-ins. |
| `restart` | Services, pods or targets to start or restart. |
| `try_restart` | Units to restart only when already active. |
| `enable` | Native systemd units to enable at boot. Quadlets use their own `[Install]` section. |
| `secrets` | Podman secrets whose rotation activates the deployment. List shared secrets for every consumer. |

Related Quadlets live together under `configs/containers/systemd/<application>/`:

```text
configs/containers/systemd/miniflux/
├── miniflux-server.container.tftpl
├── miniflux-postgres.container.tftpl
├── miniflux.pod
└── miniflux.network
```

Standalone services stay directly in `configs/containers/systemd/`. Native user
units live in `configs/systemd/user/`. Source paths map to paths under the host's
`~/.config`, with `.tftpl` removed after rendering. Every deployed file and unit
belongs to one application; the tests check ownership and isolation.

### Startup and updates

Pod-based applications restart their `<name>-pod.service`. Containers join with
`Pod=<name>.pod`, and the pod's `[Install] WantedBy=default.target` enables boot
startup. Single-container applications restart their service and declare their
own `[Install]` section. Networks and volumes start through unit dependencies.

The shared reverse-proxy network is installed before applications. Consumers use
its Podman name, `systemd-reverse-proxy`, and declare `Requires=` and `After=` on
`reverse-proxy-network.service`.

Traefik restarts its sockets and uses `try_restart` for its socket-activated
service. OpenCloud uses a native target to manage its application and extension
update timer together. Restart completion does not guarantee application
readiness; containers can still be waiting for health checks or external services.

[Common container defaults](configs/containers/systemd/container.d/10-restart.conf)
are copied into a drop-in for each container. Editing them activates every
application with containers. Before startup, containers check the data mount and
create their required application directories under `/var/mnt/docker/app_data`.

To add an application, add its files under `configs`, declare its ownership and
activation settings in `applications`, and configure its boot dependencies.
Bump the matching `secret_versions` entries after rotating Bitwarden secrets.

### Provisioning and checks

Provision a fresh host with fresh Terraform state. The Quadlet provider sets
`insecure_skip_host_key_check = true` for this homelab, so fresh or reinstalled
FCOS hosts do not require a `known_hosts` entry. SSH encrypts traffic and
authenticates the client, but does not verify the server's identity.

Run `go test ./...` from [tests](tests) to render the deployment configuration,
validate it with the installed Quadlet generator and `systemd-analyze verify`,
and check file ownership, secret isolation and directory preparation. The tests
use synthetic values and do not contact the homelab or start containers.

### Restic secrets

The root backup and prune services use [the restic wrapper](butane/restic-with-secrets.sh)
to read `restic-password`, `restic-b2-account-id`, `restic-b2-account-key`,
`restic-aws-access-key-id` and `restic-aws-secret-access-key` from core's Podman
secret store. These are installed by the same `quadlet_podman_secret.containers`
resources as application secrets.

The wrapper reads the values at each invocation, so rotation needs no service
restart. Backup jobs check secret availability before creating an LVM snapshot.

## Caveats

This is not a ready-to-use configuration that you can just apply.
It requires initialized state and personal values (DNS, Proxmox, TrueNAS, Bitwarden secret IDs, Pocket ID clients,
etc.).
You can adapt it, but copying it as-is is not realistic.
I see this repository more as a template for your own setup.

Ephemeral secrets require [my Bitwarden provider fork](https://github.com/savely-krasovsky/terraform-provider-bitwarden).
Build it with `go build -o bin/ .` and configure a development override in
`.terraformrc` pointing to that `bin/` directory. Set
`TF_CLI_CONFIG_FILE="$PWD/.terraformrc"` when running OpenTofu from this repository.

## Future plans

- [ ] Consider switching to Flatcar Linux.
- [ ] Harden network setup; some parts are still permissive.
- [ ] Integrate `hashicorp/assert` support.

[^gatus]: It lives outside this homelab host.
