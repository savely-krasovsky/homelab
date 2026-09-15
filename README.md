# Experimental Homelab

Configuration for my personal homelab: Fedora CoreOS on Proxmox, rootless Podman,
and Quadlet containers managed with OpenTofu/Terraform.

This repository reflects my hardware, storage, domains and application setup.
It is a starting point for adapting the design to another homelab; deploying it
requires the infrastructure and configuration described below.

## Architecture

- OpenTofu/Terraform provisions the FCOS VM and supplies its Ignition configuration.
  Butane defines the host's users, networking, mounts and system services.
- Applications run as systemd user services under `homelab`, using rootless Podman.
  My [Quadlet provider](https://github.com/savely-krasovsky/terraform-provider-quadlet)
  deploys rendered configuration over SSH and activates the affected applications.
- Podman storage and application data live on a separate iSCSI-backed LVM disk.
  Media, personal files and observability data use NFS shares. These persist
  independently of the VM's system disk.
- Applications use dedicated Podman networks and a shared reverse-proxy network.
  MatrixRTC uses host networking. Traefik's network aliases let containers use
  shared domain names while keeping their traffic on the host.
- Traefik uses [systemd socket activation](https://github.com/eriksjolund/podman-networking-docs?tab=readme-ov-file#socket-activation-systemd-user-service)
  to preserve source IP addresses. The host uses an nftables default-deny firewall
  and SELinux, with explicit contexts for container data where needed.
- Bitwarden Secrets Manager supplies credentials through ephemeral provider values
  and write-only resource arguments. Application and backup secrets are installed
  in Podman's secret store, keeping their values out of Ignition and Terraform state.

Grafana Alloy collects and routes metrics, logs and traces to VictoriaMetrics,
VictoriaLogs and VictoriaTraces; Grafana provides visualization. Containers opt
into scraping with `alloy.metrics.*` labels discovered over the Podman socket.
Traefik exports telemetry through OTLP, and Telegraf converts MQTT data to OTLP.

## Services

Each row corresponds to an application in [deployment.tf](deployment.tf), with
its supporting containers grouped together. The Pod column identifies applications
that share a Podman pod.

| Application | Purpose | Pod |
| --- | --- | --- |
| Actual Budget (`actual-budget`) | Budgeting | |
| Blog (`blog`) | Static personal blog | |
| Bluesky PDS (`bluesky-pds`) | ATProto personal data server | |
| CrowdSec (`crowdsec`) | Security engine and web UI | ☑️ |
| DavMail (`davmail`) | Exchange gateway | |
| Element Admin (`element-admin`) | Matrix administration UI | |
| Element Call (`element-call`) | Matrix calling client | |
| Element Web (`element-web`) | Matrix web client | |
| Forward Info Bot (`forward-info-bot`) | Telegram utility bot | |
| Glance (`glance`) | Homelab dashboard | |
| Grafana (`grafana`) | Observability dashboards | |
| Grafana Alloy (`grafana-alloy`) | Telemetry collection and routing | |
| Hister (`hister`) | Private search with llama.cpp embeddings | ☑️ |
| Immich (`immich`) | Photo and video management with machine learning | ☑️ |
| Karakeep (`karakeep`) | Bookmarks, Chrome archiving and Meilisearch | ☑️ |
| Masked Email Bot (`masked-email-bot`) | Telegram utility bot | |
| Matrix (`matrix`) | Synapse and Matrix Authentication Service | ☑️ |
| MatrixRTC (`matrix-rtc`) | LiveKit media server and JWT service | ☑️ |
| Miniflux (`miniflux`) | RSS reader | ☑️ |
| OAuth2 Proxy (`oauth2-proxy`) | Authentication proxy | ☑️ |
| Open WebUI (`open-webui`) | Chat interface and Pipelines | ☑️ |
| OpenCloud (`opencloud`) | File collaboration, Collabora and web extensions | ☑️ |
| Opengist (`opengist`) | Git-backed pastebin | |
| Outline (`outline`) | Knowledge base | ☑️ |
| Plex (`plex`) | Media server | |
| Pocket ID (`pocket-id`) | Single sign-on | |
| Podman Exporter (`prometheus-podman-exporter`) | Container metrics | |
| Prusa Exporter (`prusa-exporter`) | 3D printer metrics | |
| qBittorrent (`qbittorrent`) | BitTorrent client | |
| Remnawave (`remnawave`) | Proxy management panel and subscription page | ☑️ |
| RMQTT (`rmqtt`) | MQTT broker | |
| Static Web Server (`static-web-server`) | Static file hosting | |
| Step CA (`step-ca`) | Internal certificate authority | |
| Tangled Knot (`tangled`) | Git hosting on ATProto | |
| Telegraf (`telegraf`) | MQTT to OTLP conversion | |
| Traefik (`traefik`) | Application proxy | |
| Victoria (`victoria`) | VictoriaMetrics, VictoriaLogs, VictoriaTraces and vmauth | ☑️ |

Gatus monitors uptime from outside this homelab host.

## Repository layout

| Path | Contents |
| --- | --- |
| [main.tf](main.tf) | Provider requirements, connections and ephemeral secret reads. |
| [variables.tf](variables.tf) | Infrastructure inputs, application settings and secret IDs. |
| [fcos-stable-qcow2.tf](fcos-stable-qcow2.tf) | FCOS image download and Ignition upload. |
| [proxmox-acme.tf](proxmox-acme.tf) | Proxmox certificates and Cloudflare DNS validation. |
| [fcos.tf](fcos.tf) | VM, Podman secrets and application deployment resources. |
| [deployment.tf](deployment.tf) | Application ownership, file rendering and activation settings. |
| [butane/](butane) | Host configuration, firewall and backup wrapper. |
| [configs/](configs) | Quadlets, native user units and application configuration. |
| [tests/](tests) | Configuration and backup-wrapper checks. |
| [renovate.json](renovate.json) | Image and provider update policy. |

Related Quadlets live together under `configs/containers/systemd/<application>/`:

```text
configs/containers/systemd/miniflux/
├── miniflux-server.container.tftpl
├── miniflux-postgres.container.tftpl
├── miniflux.pod
└── miniflux.network
```

Most standalone containers live directly in `configs/containers/systemd/`.
Native user units live in `configs/systemd/user/`; other directories under
`configs/` hold application configuration. Rendered paths are relative to
`homelab`'s `~/.config`, with the `.tftpl` suffix removed.

## Prerequisites

### Infrastructure

- A Proxmox node with API and SSH access. Adapt the node name, datastores, network
  bridge, VLAN and PCI passthrough settings in `fcos.tf` to the target hardware.
- TrueNAS storage matching the mounts in `butane/fcos.yml.tftpl`: an iSCSI target
  with an existing XFS logical volume at `/dev/vg0/lv0`, and the media, personal
  and observability NFS exports. The host configuration mounts this storage;
  prepare its layout, application data and permissions before deploying.
- DNS records, a trusted CA and the external accounts used by the configuration,
  including Bitwarden, Cloudflare and backup storage. Application settings also
  contain deployment-specific OIDC client IDs and service endpoints.

### Local setup

Use OpenTofu/Terraform satisfying the version requirement in `main.tf`.
Ephemeral secrets require [my Bitwarden provider fork](https://github.com/savely-krasovsky/terraform-provider-bitwarden).
Build it with `go build -o bin/ .` in its checkout, using the Go version required
by its `go.mod`. Configure a development override in a local `.terraformrc`
pointing to that `bin/` directory. From this repository, set:

```sh
export TF_CLI_CONFIG_FILE="$PWD/.terraformrc"
```

Supply `proxmox_config`, `fcos_config` and `containers_config` from
[variables.tf](variables.tf), for example in an ignored `terraform.tfvars` file.
Replace the default Bitwarden secret IDs in `containers_secret_config` with your
own and provide the ephemeral `bws_access_token` input.

Load a key authorized for Proxmox into the SSH agent. For FCOS, keep
administrator public keys in `fcos_config.ssh_keys`; connect as `core` for
host maintenance with sudo. Set `fcos_config.ssh_private_key_path` to the
application deployment key and put its public key in
`fcos_config.homelab_ssh_keys`; the Quadlet provider connects as `homelab`.
Use separate keys for administration and application deployment.

The `homelab` account runs applications without sudo, with UID/GID `1000:1000`
and subordinate UID/GID range `524288:65536`. The administrator `core` uses
`1001:1001`. The `homelab` account can read system journals through `systemd-journal`.
Podman stores images, secrets and named volumes at `/mnt/docker/core`
(also accessible as `/var/mnt/docker/core`).

Blog uploads connect as `homelab` and write to `/var/mnt/docker/blog`, which
is owned by `homelab`.

## Deployment and updates

### Initial provisioning

After preparing the prerequisites, run from the repository root:

```sh
tofu init
tofu validate
tofu plan
tofu apply
```

The resources download the FCOS image, upload Ignition and create the VM.
Ignition configures the host on first boot. Once SSH is available, the Quadlet
provider installs the shared reverse-proxy network, application files and
secrets, then activates the applications with their required dependencies.

This homelab sets `insecure_skip_host_key_check = true`, so a fresh or reinstalled
FCOS host does not need a `known_hosts` entry. SSH encrypts traffic and authenticates
the client, but does not verify the server's identity.

### Replacing the VM

Keep the existing Terraform state when replacing a managed VM. To review a
planned replacement while the current host is reachable, run:

```sh
tofu plan -replace=proxmox_virtual_environment_vm.fcos
```

Use the same `-replace` argument with `tofu apply` to perform the replacement.
The secret and deployment resources declare `replace_triggered_by` on the VM,
so they are recreated with it. The replacement boots with Ignition and reattaches
the separate data storage. Changes to the Butane configuration take effect at
first boot; uploading a new Ignition file does not reconfigure a running host.

### Application configuration

The `applications` map in `deployment.tf` defines each deployment:

| Field | Purpose |
| --- | --- |
| `paths` | Rendered files or directories under `configs`, including the selected units' drop-ins. |
| `restart` | Services, pods or targets to start or restart. |
| `try_restart` | Units to restart only when already active. |
| `enable` | Native systemd units to enable at boot. Quadlets use their own `[Install]` section. |
| `secrets` | Podman secrets whose rotation activates the deployment. List shared secrets for every consumer. |

Every deployed file and unit has one owner. To add an application, add its files
under `configs`, declare its paths and activation settings in `applications`, and
configure its boot dependencies. Run the checks below, then review `tofu plan`
and apply the changes. File changes, secret revisions and activation settings
trigger the corresponding deployments.

### Startup and activation

Pod-based applications normally restart their `<name>-pod.service`. Containers
join with `Pod=<name>.pod`, and the pod's `[Install] WantedBy=default.target`
enables boot startup. Single-container applications restart their service and
declare their own `[Install]` section. Networks and volumes start through unit
dependencies.

Consumers of the shared reverse-proxy network use its Podman name,
`systemd-reverse-proxy`, and declare `Requires=` and `After=` on
`reverse-proxy-network.service`.

Traefik restarts its sockets and uses `try_restart` for its socket-activated
service. OpenCloud uses a native target to manage its application and extension
update timer together. Restart completion does not guarantee application
readiness; containers can still be waiting for health checks or external services.

[Common container defaults](configs/containers/systemd/container.d/10-restart.conf)
are copied into a drop-in for each container. Editing them activates every
application with containers. Before startup, containers check the data mount and
prepare their required directories under `/var/mnt/docker/app_data`.

### Secrets and image updates

After rotating a Bitwarden application or backup secret, bump its entry in
`secret_versions` and apply. Keys use the Podman secret name with hyphens, such
as `miniflux-postgres-password`. Application consumers declare these names in
`applications.<name>.secrets` so a changed secret revision activates them.
The Proxmox ACME token uses the separate `proxmox_acme_token_revision` input.

[Renovate](renovate.json) proposes image and provider updates. Selected rolling
tags use `AutoUpdate=registry`; some images are pinned by digest. OpenCloud's
extension images are refreshed by its daily systemd timer. Review updates using
the same configuration checks and plan/apply workflow.

## Backups

System restic jobs back up `/var/mnt/docker/app_data` from LVM snapshots to
Backblaze B2 and Storj daily. [The exclusions](butane/fcos.yml.tftpl) are installed
as `/etc/restic/excludes.txt`. Weekly prune jobs retain 14 daily, 8 weekly and
12 monthly snapshots. These jobs cover application data on the LVM volume;
media, personal files and observability data on NFS need their own backup policy.

The root backup and prune services use [the restic wrapper](butane/restic-with-secrets.sh)
to read `restic-password`, `restic-b2-account-id`, `restic-b2-account-key`,
`restic-aws-access-key-id` and `restic-aws-secret-access-key` from homelab's Podman
secret store. These use the same `quadlet_podman_secret.containers` resources as
application secrets.

The wrapper reads values at each invocation, so rotation needs no service
restart. Backup jobs check secret availability before creating an LVM snapshot.

## Checks

The configuration tests require Linux, Go matching [tests/go.mod](tests/go.mod),
OpenTofu (`tofu`), Podman's Quadlet generator and `systemd-analyze`. From the
repository root, run:

```sh
cd tests
go test ./...
```

The tests render configuration with synthetic values, generate Quadlet units,
validate systemd dependencies, and check file ownership, deployment isolation,
secret consumers, directory preparation and backup-secret handling. They do not
contact the homelab or start containers. The firewall syntax check also uses
`nft` and `unshare`; it skips when unprivileged network namespaces are unavailable.

## Future plans

- [ ] Consider switching to Flatcar Linux.
- [ ] Harden network setup; some parts are still permissive.
- [ ] Integrate `hashicorp/assert` support.
