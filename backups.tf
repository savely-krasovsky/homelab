locals {
  backup_jobs = {
    storj     = "06:00"
    backblaze = "07:00"
  }
}

resource "proxmox_virtual_environment_file" "file_backup" {
  for_each = local.backup_jobs

  node_name    = var.proxmox_config.node_name
  datastore_id = "local"
  content_type = "snippets"
  file_mode    = "0700"

  source_raw {
    data = templatefile("${path.module}/pve/file-backup.sh.tftpl", {
      store = each.key
    })
    file_name = "file-backup-${each.key}.sh"
  }
}

resource "proxmox_backup_job" "fcos" {
  for_each = local.backup_jobs

  id       = "fcos-${each.key}"
  node     = var.proxmox_config.node_name
  vmid     = [tostring(proxmox_virtual_environment_vm.fcos.vm_id)]
  storage  = "pbs-${each.key}"
  schedule = each.value
  enabled  = true
  mode     = "snapshot"
  script   = "/var/lib/vz/snippets/${proxmox_virtual_environment_file.file_backup[each.key].source_raw[0].file_name}"

  fleecing = {
    enabled = true
    storage = "local-zfs"
  }

  prune_backups = {
    keep-daily   = "14"
    keep-weekly  = "8"
    keep-monthly = "12"
  }
}

import {
  for_each = local.backup_jobs
  to       = proxmox_backup_job.fcos[each.key]
  id       = "fcos-${each.key}"
}
