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
    homelab = {
      source  = "registry.terraform.io/savely-krasovsky/homelab-helpers"
      version = "0.2.3"
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
  # Straight to the node: routing through Traefik cannot survive replacing the VM that
  # Traefik itself runs on.
  endpoint = "https://pve.lan.${var.containers_config.base_domain}:8006"

  // Unfortunately Proxmox can execute a lot of actions only under root user...
  username = "root@pam"
  password = ephemeral.bitwarden_secret.proxmox_password.value

  ssh {
    agent = true
  }
}
