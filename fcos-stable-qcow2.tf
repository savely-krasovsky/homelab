data "http" "fcos_stream" {
  url = "https://builds.coreos.fedoraproject.org/streams/${var.fcos_config.stream}.json"

  request_headers = {
    Accept = "application/json"
  }
}

locals {
  fcos_qemu = jsondecode(data.http.fcos_stream.response_body).architectures.x86_64.artifacts.qemu
  fcos_disk = local.fcos_qemu.formats["qcow2.xz"].disk
}

output "fcos_release" {
  value = local.fcos_qemu.release
}

resource "proxmox_download_file" "fcos_qcow2" {
  node_name    = var.proxmox_config.node_name
  datastore_id = "local"
  content_type = "iso"

  url       = local.fcos_disk.location
  file_name = "fedora-coreos-${var.fcos_config.stream}.img"

  # PVE has no xz algorithm, but its `zst` path runs `zstd -q -d -c`, which
  # reads xz too. The `.img` name passes validation that rejects `.xz`.
  checksum                = local.fcos_disk.sha256
  checksum_algorithm      = "sha256"
  decompression_algorithm = "zst"

  overwrite           = false
  overwrite_unmanaged = true

  upload_timeout = 1800
}

resource "proxmox_virtual_environment_file" "fcos_ignition" {
  node_name    = var.proxmox_config.node_name
  datastore_id = "local"
  content_type = "snippets"

  source_raw {
    data      = data.ct_config.fcos_ignition.rendered
    file_name = "fcos.ign"
  }
}
