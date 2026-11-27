# Experimental Homelab

Fedora CoreOS on Proxmox, rootless Podman and Quadlet applications managed with OpenTofu.
Adapt storage, networking and accounts before using this configuration elsewhere.

## Layout

- Fedora CoreOS VM and first-boot configuration in [fcos.tf](fcos.tf) and [butane/](butane/).
- Application deployments and Quadlets in [deployment.tf](deployment.tf) and [configs/](configs/).
- Operational guides for [storage and backups](docs/storage.md), [external Gatus](docs/gatus.md)
  and the [IPFS blog mirror](docs/ipfs.md).

## Setup

1. Prepare Proxmox API and SSH access, [host storage](docs/storage.md), DNS,
   CA trust and the required Bitwarden, Cloudflare, OIDC and backup accounts.
2. Copy [terraform.tfvars.example](terraform.tfvars.example) to `terraform.tfvars`,
   set the values and run `chmod 600 terraform.tfvars`.
3. Load the Proxmox SSH key into the agent and use the OpenTofu version required
   by [main.tf](main.tf). Set separate keys for the `core` administrator and
   the `homelab` deployment user. The Quadlet provider skips SSH host-key verification.

```sh
tofu init
tofu validate
tofu plan
tofu apply
```

## Fedora CoreOS replacement

Changes to the Ignition snippet replace the VM and its OS disk. The new VM
reattaches the external data zvol and VirtIO-FS shares and redeploys applications.
Keep the OpenTofu state and review the plan while the current VM is reachable.
Use the following command to plan a manual replacement.

```sh
tofu plan -replace=proxmox_virtual_environment_vm.fcos
```

Apply with the same `-replace` argument after reviewing the plan.

## Application changes

Add files under `configs` and register them with their systemd units in
`applications` in [deployment.tf](deployment.tf), then review and apply.
The Quadlet provider deploys over SSH to `homelab`'s `~/.config` and strips
the `.tftpl` suffix. Changes to the
[shared container defaults](configs/containers/systemd/container.d/10-restart.conf)
activate every application with containers. Check application readiness after applying.

## Secrets and updates

To redeploy a rotated Podman, Gatus or ACME secret, bump its `revision` in
`secret_config.podman`, `secret_config.gatus` or
`secret_config.proxmox_acme_cloudflare_token` and apply. List shared Podman
secrets in every consumer's `secrets` field.

For authenticated ATCR image pulls, store a Podman `auth.json` containing
only the `atcr.io` entry in Bitwarden and set `secret_config.podman.atcr-registry-auth`.
Generate the JSON with `podman login --authfile /path/to/private/auth.json atcr.io` using
an ATCR device credential or an ATProto app password.

[Renovate](renovate.json) proposes image and provider updates.
