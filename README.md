# Experimental Homelab

Fedora CoreOS on Proxmox, rootless Podman and Quadlet applications managed with OpenTofu.
This configuration is specific to this homelab; adapt storage, networking and accounts before use.

## Layout

- [main.tf](main.tf), [variables.tf](variables.tf): providers, connections and inputs.
- [fcos.tf](fcos.tf), [butane/](butane/): Fedora CoreOS VM, first-boot configuration and system services.
- [deployment.tf](deployment.tf), [configs/](configs/): application list, Quadlets and configuration.
- [storage.tf](storage.tf): existing ZFS datasets exposed through Proxmox Directory Mappings.
- [backups.tf](backups.tf): per-cloud PVE backup jobs and file-backup hooks.
- [Gatus guide](docs/gatus.md): external monitoring, configuration upload and coverage.
- [proxmox-acme.tf](proxmox-acme.tf): Proxmox certificates through Cloudflare DNS validation.
- [Storage guide](docs/storage.md): ownership, boot and recovery.

Applications run as `homelab` through the [Quadlet provider](https://github.com/savely-krasovsky/terraform-provider-quadlet).
Traefik uses socket activation; SELinux and a default-deny nftables firewall remain enabled.
Alloy sends telemetry to VictoriaMetrics/VictoriaLogs/VictoriaTraces; Grafana displays it.
Gatus monitors availability externally.

## Setup

1. Prepare Proxmox API/SSH access and the [existing storage](docs/storage.md).
   Terraform does not create or format the application pool, zvol or filesystem.
2. Configure all infrastructure addresses in `network_config`, then DNS, CA trust
   and required Bitwarden, Cloudflare, OIDC and backup accounts.
3. Use the OpenTofu version required by `main.tf`. Build the
   [Bitwarden fork](https://github.com/savely-krasovsky/terraform-provider-bitwarden)
   with `go build -o bin/ .` in its checkout and point a local `.terraformrc` development override at `bin/`.
4. Copy `terraform.tfvars.example` to ignored `terraform.tfvars`, fill in the values
   and restrict permissions with `chmod 600 terraform.tfvars`.
5. Load the Proxmox SSH key into the agent. Set Fedora CoreOS admin keys in
   `fcos_config.ssh_authorized_keys.admin`, deployment public keys in
   `fcos_config.ssh_authorized_keys.applications`, and the deployment private-key
   path in `deployment_config.ssh_private_key_path`.

```sh
export TF_CLI_CONFIG_FILE="$PWD/.terraformrc"
tofu init
tofu validate
tofu plan
tofu apply
```

Ignition configures Fedora CoreOS on first boot; the Quadlet provider then installs application
files and secrets over SSH. Uploading new Ignition does not reconfigure a running host.

The Quadlet connection currently disables SSH host-key verification: the server's
identity is not checked. Use separate admin and deployment keys.

## Fedora CoreOS access and replacement

- `core`: administrator with sudo, UID/GID `1001:1001`.
- `homelab`: applications without sudo, UID/GID `1000:1000`, subuid/subgid `524288:65536`.
- Podman storage: `/var/mnt/docker/homelab`; application data: `/var/mnt/docker/app_data`.
- Blog uploads: user `homelab`, directory `/var/mnt/docker/blog`.

Keep Terraform state and review the replacement while the current VM is reachable:

```sh
tofu plan -replace=proxmox_virtual_environment_vm.fcos
```

Apply with the same `-replace` argument only after review. The new VM receives
Ignition, reattaches the separate data storage and redeploys applications.

## Application changes

Each entry in `applications` in [deployment.tf](deployment.tf) owns its files and activation:

| Field | Purpose |
| --- | --- |
| `paths` | Files/directories under `configs`, including unit drop-ins. |
| `restart` | Units to start or restart. |
| `try_restart` | Restart only if already active. |
| `enable` | Native units enabled at boot; Quadlets use `[Install]`. |
| `secrets` | Secret names whose rotation activates this application. |

Add files under `configs`, declare their owner and activation, then review and apply.
Rendered paths are relative to `homelab`'s `~/.config`; `.tftpl` is stripped.

- Pods normally restart `<name>-pod.service`; containers join with `Pod=<name>.pod`.
  Pods and standalone containers use `[Install] WantedBy=default.target` for startup.
- Shared proxy-network consumers use `systemd-reverse-proxy` and require/order after
  `reverse-proxy-network.service`.
- Traefik activates through sockets; OpenCloud uses a native target and extension-update timer.
- [Shared container defaults](configs/containers/systemd/container.d/10-restart.conf)
  are copied to each container. Editing them activates all applications with containers.
- Restart completion is not a readiness check.

CrowdSec reads Traefik logs through `http://victoria:8427/vl/` using its dedicated token.
See [acquisition](configs/crowdsec/acquis.yaml) and [vmauth access rules](configs/vmauth/auth.yml).

## External Gatus

[Gatus](docs/gatus.md) runs on a separate VPS with its
configuration at `/home/docker-user/gatus/config/config.yml`. Service URLs use
`site_config.base_domain`; `gatus_config` supplies the interval, output directory,
Telegram chat ID and OAuth2 client ID. Check definitions and announcements live
in the template. `secret_config.gatus` contains the Bitwarden IDs and revisions
for the Telegram token, OAuth2 client secret, Remnawave API token, subscription path
and Healthchecks ping URL. The Bitwarden provider reads these secrets as one ephemeral batch.

Render locally using OpenTofu:

```sh
tofu apply -target=terraform_data.gatus_config
# Force a fresh render, for example after deleting the local file:
tofu apply -target=terraform_data.gatus_config -replace=terraform_data.gatus_config
```

The default output directory is ignored by Git; the rendered file has mode `0600`.
`gatus_config_path` outputs its absolute path. A native `terraform_data` provisioner
writes the file atomically with `printf`, receiving ephemeral content through its
environment. Secret values and rendered content are absent from plan and state.
Normal applies render when the template, settings or secret references/revisions
change. After rotating a Gatus secret, bump its `secret_config.gatus.<name>.revision`.
This does not upload or restart Gatus on the VPS.
See [upload commands](docs/gatus.md#upload-to-the-monitoring-host) and
[Gatus coverage](docs/gatus.md#coverage) for monitored applications and remaining gaps.

## Secrets and updates

Application secrets use ephemeral Bitwarden reads and write-only Podman
resource arguments. After rotation, bump `secret_config.podman.<name>.revision`
and apply. Names use hyphens; list shared secrets in every consumer's `secrets` field.
For the ACME token, bump `secret_config.proxmox_acme_cloudflare_token.revision`.

[Renovate](renovate.json) proposes image/provider updates. Selected images use
`AutoUpdate=registry`; OpenCloud extensions have a daily update timer.

## Backups

Two [PVE jobs](backups.tf) back up Fedora CoreOS and then `personal`/`observability`:
Storj at 06:00 and Backblaze at 07:00, PVE local time. OpenTofu manages the jobs
and their [file-backup hooks](pve/file-backup.sh.tftpl). Logs and results are in PVE Tasks.

Automated restore verification remains to be configured. See [backup boundaries](docs/storage.md).

## Planned

- Consider Flatcar Linux.
- Harden network configuration.
- Add `hashicorp/assert` support.
