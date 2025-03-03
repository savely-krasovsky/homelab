variable "bws_access_token" {
  description = "Bitwarden Secrets CLI access token"
  type = string
  sensitive = true
}

variable "proxmox_config" {
  description = "Proxmox credentials"
  type = object({
    endpoint = string
    password_secret_id = string
  })
}

# Just base domain for now
variable "quadlets_config" {
  description = "Shared Quadlets configuration"
  type = object({
    base_domain = string
  })
}

variable "fcos_config" {
  description = "Fedora CoreOS Configuration"
  type = object({
    hostname = string
    ssh_key = string
    root_ca = string

    mac_address = string
    ip = string
    gateway = string
    mask = string
    nameserver = string

    truenas_ip = string
    truenas_iqn = string
  })
}
