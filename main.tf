terraform {
  required_version = ">= 1.11.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.91.0"
    }
    bitwarden = {
      source = "maxlaverse/bitwarden"
      # Ephemeral secrets currently require the local .terraformrc override.
      version = "0.16.0"
    }
    ct = {
      source  = "poseidon/ct"
      version = "0.14.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
    homelab-helpers = {
      source = "registry.terraform.io/savely-krasovsky/homelab-helpers"
      # Keep the published selection for init; .terraformrc supplies the local deployment resource.
      version = "0.0.8"
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

ephemeral "bitwarden_secret" "containers" {
  for_each = var.containers_secret_config
  id       = each.value
}

provider "proxmox" {
  endpoint = "https://${var.proxmox_config.host}:8006"
  insecure = true

  // Unfortunately Proxmox can execute a lot of actions only under root user...
  username = "root@pam"
  password = ephemeral.bitwarden_secret.proxmox_password.value

  ssh {
    agent = true
  }
}
