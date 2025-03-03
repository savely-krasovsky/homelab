locals {
  butane_config = merge(var.fcos_config, {
    quadlets = local.quadlets
    networks = local.networks
  })

  # Get a list of all files in the specified directory
  quadlet_paths = fileset(path.module, "quadlets/**")
  quadlets = {
    for path in local.quadlet_paths :
    replace(basename(path), ".container.tftpl", "") => templatefile(path, var.quadlets_config)
  }

  # Same with networks
  network_paths = fileset(path.module, "networks/*")
  networks = {
    for path in local.network_paths :
    replace(basename(path), ".network", "") => file(path)
  }

  # Bitwarden Secret Manager Secret IDs
  secrets = {
    traefik-cf-dns-api-token           = "e9e0f0f0-abc8-4bde-b05f-b292018179bb"
    oauth2-proxy-cookie-secret         = "289c0832-27c2-463b-97b7-b29200a8cebd"
    oauth2-proxy-client-secret         = "afdb8ef2-a3d4-4a17-b839-b29200ab6f87"
    pocket-id-maxmind-license-key      = "08c549a4-bf48-4998-8cb0-b29200ac845d"
    actual-budget-openid-client-secret = "5754702b-d9d5-4127-b5ab-b29200abdd6a"
    open-webui-oauth-client-secret     = "b595040b-a23a-44af-8bff-b29200ad6258"
    hoarder-oauth-client-secret        = "784d379b-bcaf-424f-bc77-b29500ff1be6"
    hoarder-openai-api-key             = "98f5ccdf-d4b1-4883-b4e3-b295010ba589"
    meili-master-key                   = "a67874c5-95c2-4f7a-b335-b295010010e0"
    nextauth-secret                    = "94b4b746-f005-46e0-b60a-b29501010c06"
  }

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
    cores = 4
    affinity = "26-29"
    type = "host"
  }

  memory {
    dedicated = 16384
    floating  = 16384
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
      quadlets: local.quadlets
      secrets: local.secrets
    })
  }

  provisioner "remote-exec" {
    inline = ["sh /tmp/init.sh"]
    on_failure = fail
  }
}