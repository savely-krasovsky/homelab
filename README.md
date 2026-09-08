# Experimental Homelab

Configuration and deployment scripts for my personal homelab.

- Uses immutable, atomic Fedora CoreOS provisioned on a Proxmox VE node as a base.
- Uses rootless Podman instead of rootful Docker.
- Uses Quadlet systemd-like containers instead of Docker Compose.
- VM can be fully removed and re-provisioned in a few minutes, including container autostart.
- Provisioning is done with OpenTofu/Terraform.
- Configs are rendered from templates and synced automatically after changes.
- Secrets are provided using Bitwarden Secrets Manager.
- Ephemeral Bitwarden values are passed to the deployment provider and installed as Podman/system credentials.
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

## Applying configuration changes

Configuration is managed by `homelab-helpers_deployment.fcos` from
[terraform-provider-homelab-helpers](../terraform-provider-homelab-helpers).
The provider runs on the apply machine and transfers files over SSH/SFTP.
FCOS needs no uploaded deployment binary or Go toolchain.

The resource receives secret values through `secret_values_wo`, validates Quadlet generation
and nftables rules, atomically updates configuration, then restarts affected
systemd user units. A pod and its containers form one restart group. Mounted
configuration and shared Quadlet definitions participate in group hashes.
Podman network and volume creation options are applied when those resources are
first created.

The host manifest and pending journal are stored in `~/.local/state/homelab`.
Retry failed applies without deleting them. Refresh detects changed/missing
configuration, missing secrets and incomplete applies. It does not poll application health or compare
the live kernel firewall ruleset. Only recorded files and units are cleaned up;
application data, credentials and the host firewall survive resource destruction.

For rotated Bitwarden values, bump `deployment_secrets_revision` in your
variables and run `tofu apply`. Secret IDs are stored in Terraform state;
ephemeral secret values are excluded from plan, state and deployment fingerprints.
The Proxmox password also uses an ephemeral Bitwarden resource. The access token
is an ephemeral input used by the local Bitwarden provider.

The firewall source is [butane/nftables.nft](butane/nftables.nft), shared with
Ignition.
SSH verifies known_hosts by default; `fcos_config.ssh_host_key` can instead
pin a trusted public host key. Verify a newly created VM through a trusted console
before accepting its SSH key.

Requires OpenTofu/Terraform 1.11+. Both providers temporarily use local builds.
Build them after updating their source:

```sh
make -C ../terraform-provider-homelab-helpers build
(cd ../terraform-provider-bitwarden && CGO_ENABLED=0 go build -o bin/terraform-provider-bitwarden .)
```

Create the ignored `.terraformrc` with absolute paths to the two build directories:

```hcl
provider_installation {
  dev_overrides {
    "registry.terraform.io/savely-krasovsky/homelab-helpers" = "/absolute/path/terraform-provider-homelab-helpers/bin"
    "registry.opentofu.org/maxlaverse/bitwarden"            = "/absolute/path/terraform-provider-bitwarden/bin"
    "registry.terraform.io/maxlaverse/bitwarden"            = "/absolute/path/terraform-provider-bitwarden/bin"
  }
  direct {}
}
```

The Bitwarden clone adds `ephemeral "bitwarden_secret"`; the helpers clone adds
`homelab-helpers_deployment`. The registry versions pinned in `main.tf` and the
lock file remain installable baselines for `tofu init`. The
[development overrides](https://opentofu.org/docs/cli/config/config-file/#development-overrides-for-provider-developers)
select the local binaries for validate, plan and apply.
Builds require Go 1.27, with no C compiler, musl or SDK binaries.

From the homelab directory:

```sh
export TF_CLI_CONFIG_FILE="$PWD/.terraformrc"
tofu init
tofu validate
tofu plan
tofu apply
```

Exporting `TF_CLI_CONFIG_FILE` once keeps the same provider builds selected for
all commands. Supply `bws_access_token` through your existing variables or
`TF_VAR_bws_access_token`.

OpenCloud extensions are oneshot installers with a daily update timer. Alloy
persists its WAL and positions in `/var/mnt/docker/app_data/alloy` and uses
`alloy.grafana.<base_domain>` for its dashboard and OAuth routes.

Verification lives in the provider's Go tests (`make test vet lint`).
Homelab-specific template and Quadlet checks remain in `tests/` and run with
`go -C tests test ./...`; they use fake values and never apply to FCOS.

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

## Grafana dashboards

[Prusa Core One UDP-only dashboard](dashboards/prusa-core-one-udp.json) is available
for manual import without Loki or PrusaLink. See [dashboard notes](dashboards/README.md).

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
