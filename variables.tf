variable "bws_access_token" {
  description = "Bitwarden Secrets Manager access token."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "site_config" {
  description = "Site-wide identity and public addressing shared by applications."
  type = object({
    email       = string
    base_domain = string
    ews_domain  = string
    public_ip   = string
  })

  validation {
    condition = (
      length(trimspace(var.site_config.email)) > 0 &&
      length(trimspace(var.site_config.base_domain)) > 0 &&
      length(trimspace(var.site_config.ews_domain)) > 0 &&
      can(cidrhost("${var.site_config.public_ip}/32", 0))
    )
    error_message = "site_config requires non-empty email and domain values plus an IPv4 public_ip."
  }
}

variable "proxmox_config" {
  description = "Proxmox API connection and the node address exposed through Traefik."
  type = object({
    endpoint    = string
    node_name   = optional(string, "pve")
    upstream_ip = string
  })

  validation {
    condition = (
      startswith(var.proxmox_config.endpoint, "https://") &&
      length(trimspace(var.proxmox_config.node_name)) > 0 &&
      can(cidrhost("${var.proxmox_config.upstream_ip}/32", 0))
    )
    error_message = "proxmox_config.endpoint must use HTTPS, node_name must be non-empty, and upstream_ip must be IPv4."
  }
}

variable "fcos_config" {
  description = "Fedora CoreOS image and first-boot configuration. Changes require VM replacement to affect an existing host."
  type = object({
    stream   = optional(string, "stable")
    hostname = string
    root_ca  = string

    ssh_authorized_keys = object({
      admin        = set(string)
      applications = set(string)
    })

    network = object({
      mac_address = string
      ip          = string
      gateway     = string
      netmask     = string
      nameserver  = string
    })

    storage = object({
      truenas_ip  = string
      truenas_iqn = string
    })
  })

  validation {
    condition = (
      length(trimspace(var.fcos_config.hostname)) > 0 &&
      length(var.fcos_config.ssh_authorized_keys.admin) > 0 &&
      length(var.fcos_config.ssh_authorized_keys.applications) > 0 &&
      can(regex("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", var.fcos_config.network.mac_address)) &&
      can(cidrhost("${var.fcos_config.network.ip}/32", 0)) &&
      can(cidrhost("${var.fcos_config.network.gateway}/32", 0)) &&
      can(cidrhost("${var.fcos_config.network.nameserver}/32", 0)) &&
      can(cidrhost("${var.fcos_config.storage.truenas_ip}/32", 0))
    )
    error_message = "fcos_config requires a hostname, both SSH key sets, a valid MAC address, and IPv4 host, gateway, DNS, and TrueNAS addresses."
  }
}

variable "deployment_config" {
  description = "Machine-local settings used by OpenTofu to deploy applications over SSH."
  type = object({
    ssh_private_key_path = string
  })

  validation {
    condition     = length(trimspace(var.deployment_config.ssh_private_key_path)) > 0
    error_message = "deployment_config.ssh_private_key_path must be non-empty."
  }
}

variable "secret_config" {
  description = "Bitwarden secret references. Podman map keys are the final hyphenated secret names."
  type = object({
    proxmox_password = object({
      id = string
    })
    proxmox_acme_cloudflare_token = object({
      id       = string
      revision = optional(number, 1)
    })
    podman = map(object({
      id       = string
      revision = optional(number, 1)
    }))
  })

  validation {
    condition = (
      length(trimspace(var.secret_config.proxmox_password.id)) > 0 &&
      length(trimspace(var.secret_config.proxmox_acme_cloudflare_token.id)) > 0 &&
      var.secret_config.proxmox_acme_cloudflare_token.revision >= 1 &&
      alltrue([
        for name, secret in var.secret_config.podman :
        can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", name)) &&
        length(trimspace(secret.id)) > 0 &&
        secret.revision >= 1
      ])
    )
    error_message = "Secret IDs must be non-empty, revisions must be at least 1, and Podman secret names must use lowercase kebab-case."
  }

  validation {
    condition = length(toset(concat(
      [
        var.secret_config.proxmox_password.id,
        var.secret_config.proxmox_acme_cloudflare_token.id,
      ],
      [for secret in values(var.secret_config.podman) : secret.id],
    ))) == length(var.secret_config.podman) + 2
    error_message = "Every Bitwarden secret reference must use a distinct ID."
  }
}
