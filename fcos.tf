locals {
  containers_config = merge(var.containers_config, {
    proxmox_ip : var.proxmox_config.host,
    truenas_ip : var.fcos_config.truenas_ip,
    fcos_ip : var.fcos_config.ip,
  })

  firewall_config = file("${path.module}/butane/nftables.nft")

  butane_config = merge(var.fcos_config, {
    base_domain : var.containers_config.base_domain,
    firewall_config : local.firewall_config,
    restic_runner : file("${path.module}/butane/restic-with-secrets.sh"),
  })

  # System restic jobs read their values from core's Podman secret store at startup.
  podman_secrets = { for name, id in var.containers_secret_config : replace(name, "_", "-") => id }
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

  # Load Ignition from a file to stay within PVE's QEMU argument size limit.
  kvm_arguments = "-fw_cfg name=opt/com.coreos/config,file=/var/lib/vz/snippets/${proxmox_virtual_environment_file.fcos_ignition.source_raw[0].file_name}"
}

resource "quadlet_podman_secret" "containers" {
  for_each   = local.podman_secrets
  depends_on = [proxmox_virtual_environment_vm.fcos]

  name     = each.key
  value_wo = ephemeral.bitwarden_secrets.containers.values[lower(each.value)]
  version  = lookup(var.secret_versions, each.key, "1")

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.fcos]
  }
}

resource "quadlet_deployment" "reverse_proxy_network" {
  depends_on = [proxmox_virtual_environment_vm.fcos]

  name    = "reverse-proxy"
  files   = local.deployment_files["reverse-proxy"]
  restart = ["reverse-proxy-network.service"]

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.fcos]
  }
}

resource "quadlet_deployment" "applications" {
  # These two applications need other deployments installed before activation.
  for_each = {
    for name, app in local.applications : name => app
    if !contains(["opencloud", "oauth2-proxy"], name)
  }
  depends_on = [quadlet_deployment.reverse_proxy_network]

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

resource "quadlet_deployment" "opencloud" {
  # Collaboration waits for the Collabora URL routed through Traefik.
  depends_on = [quadlet_deployment.applications["traefik"]]

  name    = "opencloud"
  files   = local.deployment_files.opencloud
  restart = local.applications.opencloud.restart
  enable  = local.applications.opencloud.enable
  triggers = {
    for name in local.applications.opencloud.secrets : name => quadlet_podman_secret.containers[name].revision
  }

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.fcos]
  }
}

resource "quadlet_deployment" "oauth2_proxy" {
  # OIDC discovery needs both Pocket ID and the proxy serving its public URL.
  depends_on = [quadlet_deployment.applications["pocket-id"], quadlet_deployment.applications["traefik"]]

  name    = "oauth2-proxy"
  files   = local.deployment_files["oauth2-proxy"]
  restart = local.applications["oauth2-proxy"].restart
  triggers = {
    for name in local.applications["oauth2-proxy"].secrets : name => quadlet_podman_secret.containers[name].revision
  }

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.fcos]
  }
}
