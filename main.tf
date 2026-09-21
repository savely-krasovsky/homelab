terraform {
  required_version = ">= 1.11.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.114.0"
    }
    bitwarden = {
      source = "maxlaverse/bitwarden"
      # Ephemeral secrets use the Bitwarden fork configured in .terraformrc.
      version = "0.20.0"
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
      version = "0.4.2"
    }
  }
}

provider "bitwarden" {
  access_token          = var.bws_access_token
  client_implementation = "embedded"
}

ephemeral "bitwarden_secret" "proxmox_password" {
  id = var.secret_config.proxmox_password.id
}

ephemeral "bitwarden_secrets" "containers" {
  ids = toset([for secret in values(local.podman_secrets) : secret.id])
}

provider "proxmox" {
  endpoint = var.proxmox_config.endpoint

  # This configuration uses Proxmox operations restricted to root@pam.
  username = "root@pam"
  password = ephemeral.bitwarden_secret.proxmox_password.value

  ssh {
    agent = true
  }
}

provider "quadlet" {
  host                         = var.network_config.fcos_ip
  user                         = "homelab"
  private_key_file             = pathexpand(var.deployment_config.ssh_private_key_path)
  insecure_skip_host_key_check = true
}
