locals {
  // Add secrets into quadlets config
  containers_config = merge(var.containers_config, {
    proxmox_ip : var.proxmox_config.host,
    truenas_ip : var.fcos_config.truenas_ip,
    fcos_ip : var.fcos_config.ip,
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
    config_files : local.config_files,
    config_dirs : local.config_dirs,
  })

  config_rendered_files = {
    for path, content in local.config_files :
    path => content
  }

  init_script_path       = "${path.module}/scripts/init_fcos.sh.tftpl"
  get_secret_script_path = "${path.module}/scripts/get_secret.sh"
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

  kvm_arguments = "-fw_cfg 'name=opt/com.coreos/config,string=${replace(data.ct_config.fcos_ignition.rendered, ",", ",,")}' -smbios type=11,value=io.systemd.credential:bws-access-token=${var.bws_access_token}"
}

resource "null_resource" "fcos_provision_secrets" {
  depends_on = [proxmox_virtual_environment_vm.fcos]

  triggers = {
    checksum = sha256(file(local.init_script_path))
  }

  connection {
    type        = "ssh"
    user        = "core"
    private_key = file(pathexpand(var.fcos_config.ssh_private_key_path))
    host        = var.fcos_config.ip
  }

  provisioner "file" {
    destination = "/var/tmp/init.sh"
    content = templatefile(local.init_script_path, {
      config_files : local.config_files
      secret_uuids : var.containers_secret_config
    })
  }

  provisioner "file" {
    destination = "/home/core/.local/bin/get_secret.sh"
    content     = file(local.get_secret_script_path)
  }

  provisioner "remote-exec" {
    inline     = ["sh /var/tmp/init.sh"]
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
