terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.76.0"
    }
    bitwarden = {
      source = "maxlaverse/bitwarden"
      version = "0.13.6"
    }
    ct = {
      source  = "poseidon/ct"
      version = "0.13.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
    homelab-helpers = {
      source = "registry.terraform.io/savely-krasovsky/homelab-helpers"
      version = "0.0.6"
    }
  }
}

provider "bitwarden" {
  access_token = var.bws_access_token
  experimental {
    embedded_client = true
  }
}

data "bitwarden_secret" "proxmox_password" {
  id = var.proxmox_config.password_secret_id
}

provider "proxmox" {
  endpoint = "https://${var.proxmox_config.host}:8006"
  insecure = true

  // Unfortunately Proxmox can execute a lot of actions only under root user...
  username = "root@pam"
  password = data.bitwarden_secret.proxmox_password.value

  ssh {
    agent = true
  }
}
