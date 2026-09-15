# Experimental Homelab

Configuration and deployment scripts for my personal homelab.

- Uses immutable, atomic Fedora CoreOS provisioned on a Proxmox VE node as a base.
- Uses rootless Podman instead of rootful Docker.
- Uses Quadlet systemd-like containers instead of Docker Compose.
- VM can be fully removed and re-provisioned in a few minutes, including container autostart.
- Provisioning is done with OpenTofu/Terraform.
- Configs are rendered from templates and deployed over SSH by my
  [deployment provider](https://github.com/savely-krasovsky/terraform-provider-quadlet),
  with computed unit ownership and deployment-wide activation in
  [deployment.tf](deployment.tf).
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
| Gatus                                                           | Uptime Monitoring[^2]                             |     |

## Deployment policy

[deployment.tf](deployment.tf) renders the single [configs](configs) tree.
The `applications` map declares 37 independent deployments. Each entry lists
its source paths, units to restart, optional native units to enable, and secret
names to watch. Paths are relative to the host's user configuration directory;
a directory includes its contents and a unit includes its addressed drop-ins.
Every source has an explicit owner, checked by the tests.

An application owns its containers, configuration, internal network and named
volumes. For example, Miniflux owns both its server and PostgreSQL. MatrixRTC and
the Element clients can be updated independently of the Matrix homeserver.

Related Quadlets live together under `configs/containers/systemd/<application>/`:
containers, their pod, internal network and named volumes. For example:

```text
configs/containers/systemd/miniflux/
├── miniflux-server.container.tftpl
├── miniflux-postgres.container.tftpl
├── miniflux.pod
└── miniflux.network
```

Standalone containers without supporting Quadlets stay directly in
`configs/containers/systemd/`. The shared reverse-proxy network stays in
`configs/containers/systemd/networks/`; native units stay in `configs/systemd/user/`.
Source paths map directly to host paths, with only `.tftpl` removed.

| Application | Terraform resource | Activation |
| --- | --- | --- |
| Single-container applications, including Glance | `quadlet_deployment.applications["<name>"]` | Their service |
| Applications contained in one pod | `quadlet_deployment.applications["<name>"]` | Their `<name>-pod.service` |
| Traefik and its configuration and sockets | `quadlet_deployment.applications["traefik"]` | Restart sockets, then `try_restart` the service |
| OpenCloud | `quadlet_deployment.applications["opencloud"]` | `opencloud.target` |
| OAuth2 Proxy | `quadlet_deployment.applications["oauth2-proxy"]` | `oauth2-proxy-pod.service` |
| Shared reverse-proxy network | `quadlet_deployment.reverse_proxy_network` | `reverse-proxy-network.service` |

All applications use the same resource block in [fcos.tf](fcos.tf).
OpenCloud Collaboration waits for Collabora's health check and fetches discovery
directly at `http://127.0.0.1:9980` inside their pod. Collabora's `server_name`
and TLS termination settings keep the discovered browser URLs on its public
HTTPS domain. OAuth2 Proxy waits for its own Valkey; if Pocket ID or Traefik is
unavailable, the existing `Restart=always` and `RestartSec=10s` retry startup.
Its deployment can complete before OIDC discovery succeeds and login is ready.

Changing an application's files, secret installation revisions or activation
policy activates only that deployment. Shared secrets are listed for every
consumer: rotating `miniflux-postgres-password` activates Miniflux and Grafana
Alloy; rotating `vmauth-traefik-bearer-token` activates Victoria and Traefik.
Traefik owns the shared routing configuration; Alloy owns its collector config.
The provider discovers unit ownership from native files and generated Quadlets.

The shared network declares its Podman name, `systemd-reverse-proxy`,
with `NetworkName=`. Consumers use this actual name and
declare `Requires=` and `After=` on `reverse-proxy-network.service`. Terraform
installs the network deployment first.

Applications contained in one pod use the generated `<name>-pod.service` as
their entry point. The `.pod` file declares `[Install] WantedBy=default.target`
for autostart. Containers join it with `Pod=<name>.pod`; Quadlet's default
`StartWithPod=true` generates the start, stop and restart dependencies.
Networks and volumes are created through unit dependencies and remain in place
when the pod restarts. A successful pod restart reports completion of the pod
unit job; container readiness is tracked by each container's unit and health check.

OpenCloud uses a native target because it also manages an extension update
timer outside the pod. Its target starts and stops both the application and
the timer. Single containers declare their Quadlet boot links.

The [common container defaults](configs/containers/systemd/container.d/10-restart.conf) produce
an addressed drop-in for every container, so no deployment owns a global
`container.d`. This source file itself is excluded from deployment. Editing it
updates each container's copy and activates the affected deployments.

Each container checks that `/var/mnt/docker` is mounted using `ExecStartPre`.
Containers with bind mounts under `app_data` then check that the root directory
exists and create only their required subdirectories with `mkdir -p -m 0755`.
These commands live directly in the corresponding Quadlet's `[Service]` section,
run as the container host user and preserve existing permissions. A failed mount
check prevents directory creation and container startup.

### Deployment and checks

Provision a fresh host with fresh Terraform state. The provider stores ownership
and activation status in one `deployment.json` record per application.

SSH host verification uses `fcos_config.ssh_host_key` when set, otherwise
`~/.ssh/known_hosts` must contain the verified key for `fcos_config.ip`.
A key saved only for an SSH alias such as `fcos.lan` does not cover the IP.
Repeated connections rejected before authentication can trigger OpenSSH's
`PerSourcePenalties`; check the earlier SSH errors and `journalctl -u sshd`
if an apply reports many `SSH handshake: connection reset by peer` errors.

Run `go test ./...` from [tests](tests) to render the actual Terraform deployment
locals with synthetic values, validate each deployment with the installed Quadlet
generator, check the combined units with `systemd-analyze verify`, and check
directory preparation and file/secret isolation. These checks do not contact the
homelab or start containers.

To add an application, add its files under `configs` and an entry in
`applications`. Put a standalone service or the pod's generated service directly
in `restart`, and declare its boot link in the Quadlet's `[Install]` section.
The `enable` list is only for native units, such as Traefik's sockets or
OpenCloud's target. Use a target when an application needs to manage additional
units outside its pod, such as a timer.

### Restic secrets

Restic uses the same `quadlet_podman_secret.containers` resources as applications:
`restic-password`, `restic-b2-account-id`, `restic-b2-account-key`,
`restic-aws-access-key-id` and `restic-aws-secret-access-key`.
Ignition installs `/etc/restic/run` as root. The system services use this wrapper
to read the selected backend's secrets as `core`, then execute restic as root for
snapshot access. Values travel through pipes and the restic process environment;
no secret value is embedded in the wrapper or unit files.

Bump the matching `secret_versions` entries after a Bitwarden rotation. The next
backup or prune invocation reads the installed values, so no service restart is
needed. Backup units check that secrets can be read before creating a snapshot.
A missing secret fails the job. This depends on core's Podman storage being
available, already covered by the units' `/var/mnt/docker` mount requirement.

## Caveats

This is not a ready-to-use configuration that you can just apply.
It requires initialized state and personal values (DNS, Proxmox, TrueNAS, Bitwarden secret IDs, Pocket ID clients,
etc.).
You can adapt it, but copying it as-is is not realistic.
I see this repository more as a template for your own setup.

Applying also needs a patched Bitwarden provider: the released `maxlaverse/bitwarden` 0.18.0 has no
ephemeral resources at all, so both `ephemeral "bitwarden_secret"` and `ephemeral "bitwarden_secrets"`
come from [my fork](https://github.com/savely-krasovsky/terraform-provider-bitwarden) — `v0.18.0` plus
commits `aa47a52` and `042ae61`, upstream as [PR #406](https://github.com/maxlaverse/terraform-provider-bitwarden/pull/406).
Build it with `go build -o bin/ .` and point `.terraformrc` at that `bin/` directory.

## Future plans

- [x] Move Traefik, Grafana Alloy and other configs to the repository.
- [ ] Consider switching to Flatcar Linux. I still like it more, but missing pieces were a blocker.
- [x] Monitor uptime and setup alerts with an external monitor[^1].
- [ ] Harden network setup; some parts are still permissive.
- [ ] Integrate `hashicorp/assert` support.

[^1]: It lives outside this repository.
[^2]: It lives outside this homelab host.
