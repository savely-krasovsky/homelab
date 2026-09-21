locals {
  template_config = merge(var.site_config, var.network_config)

  firewall_config = templatefile("${path.module}/butane/nftables.nft.tftpl", {
    gateway_ip = var.network_config.gateway_ip
  })

  butane_config = {
    hostname : var.fcos_config.hostname,
    ssh_keys : var.fcos_config.ssh_authorized_keys.admin,
    homelab_ssh_keys : var.fcos_config.ssh_authorized_keys.applications,
    root_ca : var.fcos_config.root_ca,
    fcos_mac_address : var.network_config.fcos_mac_address,
    fcos_ip : var.network_config.fcos_ip,
    gateway_ip : var.network_config.gateway_ip,
    subnet_mask : cidrnetmask("0.0.0.0/${var.network_config.subnet_prefix}"),
    dns_ip : var.network_config.dns_ip,
    data_pv_uuid : var.fcos_config.storage.data_pv_uuid,
    base_domain : var.site_config.base_domain,
    firewall_config : local.firewall_config,
  }

  required_podman_secret_names = toset(flatten([
    for _, application in local.applications : try(application.secrets, [])
  ]))

  # The indexed map makes a missing required tfvars entry fail during planning.
  # Merging it back preserves additional secrets without changing their resource addresses.
  podman_secrets = merge(
    var.secret_config.podman,
    { for name in local.required_podman_secret_names : name => var.secret_config.podman[name] },
  )
}

data "ct_config" "fcos_ignition" {
  content = templatefile("${path.module}/butane/fcos.yml.tftpl", local.butane_config)
  strict  = true
}

resource "proxmox_virtual_environment_vm" "fcos" {
  node_name   = var.proxmox_config.node_name
  name        = "fcos"
  description = "Managed by OpenTofu"
  # Requires the host's OpenZFS boot integration documented in docs/storage.md.
  # Generated dataset mount units gate pve-guests.service on successful unlock.
  on_boot = true

  lifecycle {
    ignore_changes = [
      disk["file_id"]
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
    file_id      = proxmox_download_file.fcos_qcow2.id
    size         = 32
    discard      = "on"
    backup       = false
  }

  # Attach the existing zvol; never allocate/import/copy it into a VM-owned disk.
  # Its lifetime is independent of this VM. Keep datastore_id empty.
  disk {
    interface         = "scsi1"
    datastore_id      = ""
    path_in_datastore = var.fcos_config.storage.data_device
    file_format       = "raw"
    aio               = "io_uring"
    cache             = "none"
    discard           = "on"
    backup            = true
    replicate         = false
    iothread          = true
    serial            = "homelab-data"
  }

  # Preserve the tested virtiofs0/1/2 order, not alphabetical map ordering.
  dynamic "virtiofs" {
    for_each = ["media", "personal", "observability", "random"]
    content {
      mapping    = proxmox_hardware_mapping_dir.fcos[virtiofs.value].name
      cache      = "auto"
      expose_acl = true
      # ACL support implies xattrs in PVE; keep provider state in agreement.
      expose_xattr = true
    }
  }

  tpm_state {
    datastore_id = "local-zfs"
  }

  network_device {
    bridge      = var.network_config.bridge
    vlan_id     = var.network_config.vlan_id
    mac_address = var.network_config.fcos_mac_address
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

  # Load Ignition from a file to stay within PVE's QEMU argument size limit.
  kvm_arguments = "-fw_cfg name=opt/com.coreos/config,file=/var/lib/vz/snippets/${proxmox_virtual_environment_file.fcos_ignition.source_raw[0].file_name}"
}

resource "terraform_data" "fcos_ready" {
  depends_on = [proxmox_virtual_environment_vm.fcos]

  connection {
    type        = "ssh"
    host        = var.network_config.fcos_ip
    user        = "homelab"
    private_key = sensitive(file(pathexpand(var.deployment_config.ssh_private_key_path)))
    agent       = false
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "systemctl is-active --quiet systemd-user-sessions.service",
      "mountpoint -q /var/mnt/docker",
      "mountpoint -q /var/mnt/media",
      "mountpoint -q /var/mnt/personal",
      "mountpoint -q /var/mnt/observability",
      "mountpoint -q /var/mnt/random",
      "systemctl --user is-active --quiet default.target",
      "podman info --format '{{.Store.GraphRoot}}'",
    ]
  }

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.fcos]
  }
}

resource "quadlet_podman_secret" "containers" {
  for_each   = local.podman_secrets
  depends_on = [terraform_data.fcos_ready]

  name     = each.key
  value_wo = ephemeral.bitwarden_secrets.containers.values[lower(each.value.id)]
  version  = tostring(each.value.revision)
}

resource "quadlet_deployment" "reverse_proxy_network" {
  depends_on = [terraform_data.fcos_ready]

  name    = "reverse-proxy"
  files   = local.deployment_files["reverse-proxy"]
  restart = ["reverse-proxy-network.service"]

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.fcos]
  }
}

resource "quadlet_deployment" "socket_proxy" {
  depends_on = [terraform_data.fcos_ready]

  name    = "socket-proxy"
  files   = local.deployment_files["socket-proxy"]
  restart = ["socket-proxy.service"]

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.fcos]
  }
}

resource "quadlet_deployment" "applications" {
  for_each   = local.applications
  depends_on = [quadlet_deployment.reverse_proxy_network, quadlet_deployment.socket_proxy]

  name        = each.key
  files       = local.deployment_files[each.key]
  restart     = each.value.restart
  try_restart = try(each.value.try_restart, [])
  enable      = try(each.value.enable, [])
  triggers = {
    for name in try(each.value.secrets, []) : name => quadlet_podman_secret.containers[name].revision
  }

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.fcos]
  }
}
