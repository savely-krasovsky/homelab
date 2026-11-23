variable "bws_access_token" {
  description = "Bitwarden Secrets Manager access token."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "site_config" {
  description = "Site-wide identity shared by applications."
  type = object({
    email       = string
    base_domain = string
    ews_domain  = string
  })
}

variable "network_config" {
  description = "Network topology and infrastructure addresses."
  type = object({
    public_ip        = string
    gateway_ip       = string
    dns_ip           = string
    pve_ip           = string
    pbs_ip           = string
    fcos_ip          = string
    fcos_mac_address = string
    subnet_prefix    = number
    bridge           = optional(string, "vmbr0")
    vlan_id          = optional(number, 100)
  })

  validation {
    condition = alltrue([
      for ip in [
        var.network_config.fcos_ip,
        var.network_config.gateway_ip,
        var.network_config.dns_ip,
      ] : can(cidrnetmask("${ip}/32"))
    ])
    error_message = "Fedora CoreOS requires IPv4 addresses for fcos_ip, gateway_ip, and dns_ip at boot."
  }
}

variable "proxmox_config" {
  description = "Proxmox API connection."
  type = object({
    endpoint  = string
    node_name = optional(string, "pve")
  })

  validation {
    condition     = startswith(var.proxmox_config.endpoint, "https://")
    error_message = "proxmox_config.endpoint must use HTTPS."
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

    storage = object({
      data_device  = string
      data_pv_uuid = string
      shares = object({
        media         = string
        personal      = string
        observability = string
        random        = string
      })
    })
  })

  validation {
    condition = (
      length(var.fcos_config.ssh_authorized_keys.admin) > 0 &&
      length(var.fcos_config.ssh_authorized_keys.applications) > 0
    )
    error_message = "Configure at least one SSH key for each of the core and homelab users."
  }

  validation {
    condition = (
      can(regex("^/dev/zvol/[A-Za-z0-9_./-]+$", var.fcos_config.storage.data_device)) &&
      can(regex("^[A-Za-z0-9]{6}(-[A-Za-z0-9]{4}){5}-[A-Za-z0-9]{6}$", var.fcos_config.storage.data_pv_uuid)) &&
      alltrue([for path in values(var.fcos_config.storage.shares) : startswith(path, "/") && path != "/"])
    )
    error_message = "Use a /dev/zvol/... device path, an LVM PV UUID, and absolute dataset mount paths below the root directory."
  }
}

variable "deployment_config" {
  description = "Machine-local settings used by OpenTofu to deploy applications over SSH."
  type = object({
    ssh_private_key_path = string
  })
}

variable "gatus_config" {
  description = "External Gatus checks and the local render directory."
  type = object({
    interval         = optional(string, "1m")
    output_directory = optional(string, ".build/ch-vps01/gatus")
    telegram_chat_id = string
    oauth2_client_id = string
  })
}

variable "secret_config" {
  description = "Bitwarden secret references. Map keys use hyphenated secret names; Podman keys are also the installed names."
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
    gatus = map(object({
      id       = string
      revision = optional(number, 1)
    }))
  })

  validation {
    condition = length(toset(concat(
      [
        var.secret_config.proxmox_password.id,
        var.secret_config.proxmox_acme_cloudflare_token.id,
      ],
      [for secret in values(var.secret_config.podman) : secret.id],
      [for secret in values(var.secret_config.gatus) : secret.id],
    ))) == length(var.secret_config.podman) + length(var.secret_config.gatus) + 2
    error_message = "Every Bitwarden secret reference must use a distinct ID."
  }
}
