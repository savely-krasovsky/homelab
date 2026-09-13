ephemeral "bitwarden_secret" "acme_cf_token" {
  id = var.proxmox_config.acme_cf_token_secret_id
}

resource "proxmox_acme_account" "homelab" {
  name      = "homelab"
  contact   = var.containers_config.email
  directory = "https://acme-v02.api.letsencrypt.org/directory"
  tos       = "https://letsencrypt.org/documents/LE-SA-v1.8-July-06-2026.pdf"
}

resource "proxmox_acme_dns_plugin" "cloudflare" {
  # `plugin` is the id this config is stored under; `api` selects acme.sh's
  # handler and must be `cf` — `cloudflare` is rejected.
  plugin = "cloudflare"
  api    = "cf"

  data_wo = {
    CF_Token = ephemeral.bitwarden_secret.acme_cf_token.value
  }
  data_wo_version = var.proxmox_acme_token_revision
}

resource "proxmox_acme_certificate" "pve" {
  account   = proxmox_acme_account.homelab.name
  node_name = "pve"
  force     = true

  # pve.<domain> is what every service CNAMEs to and is reached through Traefik; the
  # second name is a leaf that resolves straight to the node, so overriding it locally
  # cannot drag the rest of the zone onto the hypervisor.
  domains = [
    for name in ["pve", "pve.lan"] : {
      domain = "${name}.${var.containers_config.base_domain}"
      plugin = proxmox_acme_dns_plugin.cloudflare.plugin
    }
  ]
}
