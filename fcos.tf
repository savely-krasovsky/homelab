data "bitwarden_secret" "victoria_bearer_token" {
  id = var.quadlets_secret_config.victoria_bearer_token
}

data "bitwarden_secret" "immich_map_key" {
  id = var.quadlets_secret_config.immich_map_key
}

locals {
  // Add secrets into quadlets config
  quadlets_config = merge(var.quadlets_config, {
    secrets: {
      victoria_bearer_token: data.bitwarden_secret.victoria_bearer_token.value
      immich_map_key = data.bitwarden_secret.immich_map_key.value
    }
  })

  # Get a list of all files in the specified directory
  quadlet_paths = fileset(path.module, "quadlets/**")
  quadlet_files = {
    for path in local.quadlet_paths :
    replace(basename(path), ".tftpl", "") => templatefile(path, local.quadlets_config)
  }

  butane_config = merge(var.fcos_config, {
    quadlet_files = local.quadlet_files
  })

  init_script_path = "${path.module}/scripts/init_fcos.sh.tftpl"
}

data "ct_config" "fcos_ignition" {
  content = templatefile("${path.module}/butane/fcos.yml.tftpl", local.butane_config)
  strict = true
}

resource "proxmox_virtual_environment_vm" "fcos" {
  node_name = "pve"
  name      = "fcos"
  description = "Managed by OpenTofu"

  # Use modern platform
  machine = "q35"
  bios    = "ovmf"

  startup {
    order = 11
  }

  cpu {
    cores = 8
    affinity = "6-7,24-29"
    type = "host"
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
    bridge = "vmbr0"
    vlan_id = 100
    mac_address = var.fcos_config.mac_address
  }

  # Linux 6.x
  operating_system {
    type = "l26"
  }

  # Intel A380 video
  hostpci {
    device = "hostpci0"
    id     = "0000:03:00.0"
    pcie   = true
    rombar = true
  }

  # Intel A380 audio
  hostpci {
    device = "hostpci1"
    id     = "0000:04:00.0"
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
    type = "ssh"
    user = "core"
    agent = true
    host = var.fcos_config.ip
  }

  provisioner "file" {
    destination = "/tmp/init.sh"
    content = templatefile(local.init_script_path, {
      bws_access_token: var.bws_access_token
      quadlet_files: local.quadlet_files
      secrets: var.quadlets_secret_config
    })
  }

  provisioner "remote-exec" {
    inline = ["sh /tmp/init.sh"]
    on_failure = fail
  }
}