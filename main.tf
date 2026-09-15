terraform {
  required_version = ">= 1.11.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.113.1"
    }
    bitwarden = {
      source = "maxlaverse/bitwarden"
      # Ephemeral secrets use the Bitwarden fork configured in .terraformrc.
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
      version = "0.4.2"
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
  # Direct node access keeps provisioning independent of Traefik.
  endpoint = "https://pve.lan.${var.containers_config.base_domain}:8006"

  # This configuration uses Proxmox operations restricted to root@pam.
  username = "root@pam"
  password = ephemeral.bitwarden_secret.proxmox_password.value

  ssh {
    agent = true
  }
}

provider "quadlet" {
  host                         = var.fcos_config.ip
  user                         = "core"
  private_key_file             = pathexpand(var.fcos_config.ssh_private_key_path)
  insecure_skip_host_key_check = true
}
