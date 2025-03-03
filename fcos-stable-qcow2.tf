resource "null_resource" "fcos_qcow2" {
  provisioner "local-exec" {
    command = "mv $(docker run --security-opt label=disable --pull=always --rm -v .:/data -w /data quay.io/coreos/coreos-installer:release download -p qemu -f qcow2.xz -s stable -a x86_64 -d) fedora-coreos.qcow2.img"
    interpreter = ["PowerShell", "-Command"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f fedora-coreos.qcow2.img"
    interpreter = ["PowerShell", "-Command"]
  }
}

resource "proxmox_virtual_environment_file" "fcos_qcow2" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"

  depends_on = [null_resource.fcos_qcow2]

  source_file {
    path = "fedora-coreos.qcow2.img"
  }
}
