locals {
  # Shared template values. Secret contents are passed only through secret_values_wo.
  containers_config = merge(var.containers_config, {
    proxmox_ip : var.proxmox_config.host,
    truenas_ip : var.fcos_config.truenas_ip,
    fcos_ip : var.fcos_config.ip,
  })

  # Get a list of all files in the specified directory
  config_paths = fileset("${path.module}/configs", "**")
  config_files = {
    for cfgpath in local.config_paths :
    trimsuffix(cfgpath, ".tftpl") => templatefile("${path.module}/configs/${cfgpath}", local.containers_config)
  }
  # Terraform hasn't directory alternative for fileset method
  config_dirs = provider::homelab-helpers::dirset("${path.module}/configs", "**")

  butane_config = merge(var.fcos_config, {
    config_files : local.config_files,
    config_dirs : local.config_dirs,
    base_domain : var.containers_config.base_domain,
    firewall_config : local.firewall_config,
  })
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
  machine       = "q35"
  bios          = "ovmf"
  scsi_hardware = "virtio-scsi-single"

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
    datastore_id      = "local-zfs"
    type              = "4m"
    pre_enrolled_keys = true
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

resource "homelab-helpers_deployment" "fcos" {
  depends_on = [proxmox_virtual_environment_vm.fcos]

  host             = var.fcos_config.ip
  user             = "core"
  private_key_file = pathexpand(var.fcos_config.ssh_private_key_path)
  host_key         = var.fcos_config.ssh_host_key

  files            = local.config_files
  units            = local.managed_units
  groups           = local.deployment_groups
  firewall         = local.firewall_config
  secrets          = var.containers_secret_config
  secrets_revision = var.deployment_secrets_revision

  secret_values_wo = {
    for name, secret in ephemeral.bitwarden_secret.containers : name => secret.value
  }

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.fcos]
  }
}
