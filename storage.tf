# Native Datacenter -> Resource Mappings -> Directory entries.
# These reference existing mounted ZFS datasets; they neither format disks nor
# create Directory storage under Node -> Disks. Pool/key boot configuration uses
# the host's upstream OpenZFS integration; see docs/storage.md.
resource "proxmox_hardware_mapping_dir" "fcos" {
  for_each = var.fcos_config.storage.shares

  name = "homelab-${each.key}"
  map = [{
    node = var.proxmox_config.node_name
    path = each.value
  }]

  lifecycle {
    prevent_destroy = true
  }
}
