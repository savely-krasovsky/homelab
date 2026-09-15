terraform {
  required_version = ">= 1.11.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.113.1"
    }
    bitwarden = {
      source = "maxlaverse/bitwarden"
      # Ephemeral secrets currently require the local .terraformrc override.
      version = "0.18.0"
    }
    ct = {
      source  = "poseidon/ct"
      version = "0.14.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.6.2"
    }
    quadlet = {
      source  = "registry.terraform.io/savely-krasovsky/quadlet"
      version = "0.4.1"
    }
  }
}

provider "bitwarden" {
  access_token          = var.bws_access_token
  client_implementation = "embedded"
}

ephemeral "bitwarden_secret" "proxmox_password" {
  id = var.proxmox_config.password_secret_id
}

ephemeral "bitwarden_secrets" "containers" {
  ids = toset(values(var.containers_secret_config))
}

provider "proxmox" {
  # Straight to the node: Traefik runs on the VM being replaced
  endpoint = "https://pve.lan.${var.containers_config.base_domain}:8006"

  // Unfortunately Proxmox can execute a lot of actions only under root user...
  username = "root@pam"
  password = ephemeral.bitwarden_secret.proxmox_password.value

  ssh {
    agent = true
  }
}

provider "quadlet" {
  host             = var.fcos_config.ip
  user             = "core"
  private_key_file = pathexpand(var.fcos_config.ssh_private_key_path)
  host_key         = var.fcos_config.ssh_host_key
}
