ephemeral "bitwarden_secret" "acme_cf_token" {
  id = var.secret_config.proxmox_acme_cloudflare_token.id
}

resource "proxmox_acme_account" "homelab" {
  name      = "homelab"
  contact   = var.site_config.email
  directory = "https://acme-v02.api.letsencrypt.org/directory"
  tos       = "https://letsencrypt.org/documents/LE-SA-v1.8-July-06-2026.pdf"
}

resource "proxmox_acme_dns_plugin" "cloudflare" {
  # api must be cf; cloudflare is rejected
  plugin = "cloudflare"
  api    = "cf"

  data_wo = {
    CF_Token = ephemeral.bitwarden_secret.acme_cf_token.value
  }
  data_wo_version = var.secret_config.proxmox_acme_cloudflare_token.revision
}

resource "proxmox_acme_certificate" "pve" {
  account   = proxmox_acme_account.homelab.name
  node_name = var.proxmox_config.node_name
  force     = true

  # pve.lan is the leaf that resolves straight to the node; pve.<domain> goes through Traefik
  domains = [
    for name in ["pve", "pve.lan"] : {
      domain = "${name}.${var.site_config.base_domain}"
      plugin = proxmox_acme_dns_plugin.cloudflare.plugin
    }
  ]
}
