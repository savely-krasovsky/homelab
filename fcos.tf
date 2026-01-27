data "bitwarden_secret" "vmauth_traefik_bearer_token" {
  id = var.containers_secret_config.vmauth_traefik_bearer_token
}

data "bitwarden_secret" "vmauth_proxmox_bearer_token" {
  id = var.containers_secret_config.vmauth_proxmox_bearer_token
}

data "bitwarden_secret" "immich_map_key" {
  id = var.containers_secret_config.immich_map_key
}

// Matrix secrets
data "bitwarden_secret" "coturn_turn_shared_secret" {
  id = var.containers_secret_config.coturn_turn_shared_secret
}
data "bitwarden_secret" "synapse_postgres_password" {
  id = var.containers_secret_config.synapse_postgres_password
}
data "bitwarden_secret" "synapse_registration_shared_secret" {
  id = var.containers_secret_config.synapse_registration_shared_secret
}
data "bitwarden_secret" "synapse_macaroon_secret_key" {
  id = var.containers_secret_config.synapse_macaroon_secret_key
}
data "bitwarden_secret" "synapse_form_secret" {
  id = var.containers_secret_config.synapse_form_secret
}
data "bitwarden_secret" "synapse_oidc_client_secret" {
  id = var.containers_secret_config.synapse_oidc_client_secret
}
data "bitwarden_secret" "matrix_authentication_service_postgres_password" {
  id = var.containers_secret_config.matrix_authentication_service_postgres_password
}
data "bitwarden_secret" "matrix_authentication_service_secret" {
  id = var.containers_secret_config.matrix_authentication_service_secret
}
data "bitwarden_secret" "matrix_authentication_service_secrets_encryption" {
  id = var.containers_secret_config.matrix_authentication_service_secrets_encryption
}
data "bitwarden_secret" "matrix_authentication_service_secrets_rsa_key" {
  id = var.containers_secret_config.matrix_authentication_service_secrets_rsa_key
}
data "bitwarden_secret" "matrix_authentication_service_secrets_p256_key" {
  id = var.containers_secret_config.matrix_authentication_service_secrets_p256_key
}
data "bitwarden_secret" "matrix_authentication_service_secrets_p384_key" {
  id = var.containers_secret_config.matrix_authentication_service_secrets_p384_key
}
data "bitwarden_secret" "matrix_authentication_service_secrets_secp256k1_key" {
  id = var.containers_secret_config.matrix_authentication_service_secrets_secp256k1_key
}
data "bitwarden_secret" "matrix_authentication_service_smtp_password" {
  id = var.containers_secret_config.matrix_authentication_service_smtp_password
}
data "bitwarden_secret" "matrix_rtc_livekit_key" {
  id = var.containers_secret_config.matrix_rtc_livekit_key
}
data "bitwarden_secret" "matrix_rtc_livekit_secret" {
  id = var.containers_secret_config.matrix_rtc_livekit_secret
}

# Remnawave
data "bitwarden_secret" "remnawave_metrics_pass" {
  id = var.containers_secret_config.remnawave_metrics_pass
}
data "bitwarden_secret" "remnawave_xhttp_path" {
  id = var.containers_secret_config.remnawave_xhttp_path
}

# Crowdsec
data "bitwarden_secret" "crowdsec_lapi_key" {
  id = var.containers_secret_config.crowdsec_lapi_key
}

locals {
  // Add secrets into quadlets config
  containers_config = merge(var.containers_config, {
    proxmox_ip : var.proxmox_config.host,
    truenas_ip : var.fcos_config.truenas_ip,
    fcos_ip : var.fcos_config.ip,
    secrets : {
      vmauth_traefik_bearer_token : data.bitwarden_secret.vmauth_traefik_bearer_token.value
      vmauth_proxmox_bearer_token : data.bitwarden_secret.vmauth_proxmox_bearer_token.value
      immich_map_key : data.bitwarden_secret.immich_map_key.value
      coturn_turn_shared_secret : data.bitwarden_secret.coturn_turn_shared_secret.value
      synapse_postgres_password : data.bitwarden_secret.synapse_postgres_password.value
      synapse_registration_shared_secret : data.bitwarden_secret.synapse_registration_shared_secret.value
      synapse_macaroon_secret_key : data.bitwarden_secret.synapse_macaroon_secret_key.value
      synapse_form_secret : data.bitwarden_secret.synapse_form_secret.value
      synapse_oidc_client_secret : data.bitwarden_secret.synapse_oidc_client_secret.value
      matrix_authentication_service_postgres_password : data.bitwarden_secret.matrix_authentication_service_postgres_password.value
      matrix_authentication_service_secret : data.bitwarden_secret.matrix_authentication_service_secret.value
      matrix_authentication_service_secrets_encryption : data.bitwarden_secret.matrix_authentication_service_secrets_encryption.value
      matrix_authentication_service_secrets_rsa_key : data.bitwarden_secret.matrix_authentication_service_secrets_rsa_key.value
      matrix_authentication_service_secrets_p256_key : data.bitwarden_secret.matrix_authentication_service_secrets_p256_key.value
      matrix_authentication_service_secrets_p384_key : data.bitwarden_secret.matrix_authentication_service_secrets_p384_key.value
      matrix_authentication_service_secrets_secp256k1_key : data.bitwarden_secret.matrix_authentication_service_secrets_secp256k1_key.value
      matrix_authentication_service_smtp_password : data.bitwarden_secret.matrix_authentication_service_smtp_password.value
      matrix_rtc_livekit_key : data.bitwarden_secret.matrix_rtc_livekit_key.value
      matrix_rtc_livekit_secret : data.bitwarden_secret.matrix_rtc_livekit_secret.value
      remnawave_metrics_pass : data.bitwarden_secret.remnawave_metrics_pass.value
      remnawave_xhttp_path : data.bitwarden_secret.remnawave_xhttp_path.value
      crowdsec_lapi_key : data.bitwarden_secret.crowdsec_lapi_key.value
    }
  })

  # Get a list of all files in the specified directory
  config_paths = fileset("${path.module}/configs", "**")
  config_files = {
    for cfgpath in local.config_paths :
    replace(cfgpath, ".tftpl", "") => templatefile("${path.module}/configs/${cfgpath}", local.containers_config)
  }
  # Terraform hasn't directory alternative for fileset method
  config_dirs = provider::homelab-helpers::dirset("${path.module}/configs", "**")

  butane_config = merge(var.fcos_config, {
    config_files : local.config_files
    config_dirs : local.config_dirs,
  })

  config_rendered_files = {
    for path, content in local.config_files :
    path => content
  }

  init_script_path = "${path.module}/scripts/init_fcos.sh.tftpl"
}

output "directories_to_create" {
  value = local.config_dirs
}

data "ct_config" "fcos_ignition" {
  content = templatefile("${path.module}/butane/fcos.yml.tftpl", local.butane_config)
  strict  = true
}

resource "proxmox_virtual_environment_vm" "fcos" {
  node_name   = "pve"
  name        = "fcos"
  description = "Managed by OpenTofu"

  lifecycle {
    ignore_changes = [
      disk["file_id"],
      kvm_arguments
    ]
  }

  # Use modern platform
  machine = "q35"
  bios    = "ovmf"

  startup {
    order = 20
  }

  cpu {
    cores = 16
    type  = "Skylake-Client-v4"
  }

  memory {
    dedicated = 32768
    floating  = 32768
  }

  efi_disk {
    datastore_id = "local-zfs"
    type         = "4m"
  }

  disk {
    interface    = "virtio0"
    datastore_id = "local-zfs"
    file_id      = proxmox_virtual_environment_file.fcos_qcow2.id
    size         = 32
  }

  tpm_state {
    datastore_id = "local-zfs"
  }

  network_device {
    bridge      = "vmbr0"
    vlan_id     = 100
    mac_address = var.fcos_config.mac_address
  }

  # Linux 6.x
  operating_system {
    type = "l26"
  }

  # Intel Arc Pro B50 video
  hostpci {
    device = "hostpci0"
    id     = "0000:03:00.1"
    pcie   = true
    rombar = true
  }

  agent {
    enabled = true
  }

  kvm_arguments = "-fw_cfg 'name=opt/com.coreos/config,string=${replace(data.ct_config.fcos_ignition.rendered, ",", ",,")}'"
}

resource "null_resource" "fcos_provision_secrets" {
  depends_on = [proxmox_virtual_environment_vm.fcos]

  triggers = {
    checksum = sha256(file(local.init_script_path))
  }

  connection {
    type  = "ssh"
    user  = "core"
    agent = true
    host  = var.fcos_config.ip
  }

  provisioner "file" {
    destination = "/tmp/init.sh"
    content = templatefile(local.init_script_path, {
      bws_access_token : var.bws_access_token
      config_files : local.config_files
      secrets : var.containers_secret_config
    })
  }

  provisioner "remote-exec" {
    inline     = ["sh /tmp/init.sh"]
    on_failure = fail
  }
}

resource "null_resource" "sync_configs" {
  depends_on = [proxmox_virtual_environment_vm.fcos]

  triggers = {
    configs_hash = provider::homelab-helpers::dirhash("${path.module}/configs", "**")
  }

  connection {
    type        = "ssh"
    user        = "core"
    private_key = file(pathexpand(var.fcos_config.ssh_private_key_path))
    host        = var.fcos_config.ip
  }

  // Create directories if not exist
  provisioner "remote-exec" {
    inline = distinct([
      for path, _ in local.config_rendered_files :
      "mkdir -p /var/home/core/.config/${replace(dirname(path), "\\", "/")}"
    ])
  }

  // Copy files, but remove the last byte to avoid double newline
  provisioner "remote-exec" {
    inline = [
      for path, content in local.config_rendered_files : <<-EOT
        cat <<'EOF' | head -c -1 > "/var/home/core/.config/${path}"
        ${content}
        EOF
      EOT
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "systemctl --user daemon-reload"
    ]
  }
}
