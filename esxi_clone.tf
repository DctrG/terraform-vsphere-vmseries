resource "terraform_data" "esxi_disk_clone" {
  count = local.clone_with_esxi ? 1 : 0

  input = {
    source_vmdk_path      = var.ova.source_image_vmdk_path
    destination_vmdk_path = local.esxi_disk_vmfs_path
    destination_directory = local.esxi_disk_vmfs_dir
    disk_clone_type       = var.ova.source_image_disk_clone_type
  }

  triggers_replace = [
    var.ova.source_image_vmdk_path,
    local.esxi_disk_vmfs_path,
    var.ova.source_image_disk_clone_type
  ]

  connection {
    type        = "ssh"
    host        = var.esxi_ssh_host
    user        = var.esxi_ssh_user
    password    = var.esxi_ssh_password
    private_key = var.esxi_ssh_private_key
    port        = var.esxi_ssh_port
    timeout     = var.esxi_ssh_timeout
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "mkdir -p ${local.esxi_disk_vmfs_dir_shell}",
      "test -f ${local.esxi_source_vmdk_shell}",
      "if [ -f ${local.esxi_disk_vmfs_path_shell} ]; then vmkfstools -U ${local.esxi_disk_vmfs_path_shell}; fi",
      "vmkfstools -i ${local.esxi_source_vmdk_shell} ${local.esxi_disk_vmfs_path_shell} -d ${local.esxi_disk_clone_type_shell}"
    ]
  }

  lifecycle {
    precondition {
      condition     = var.esxi_ssh_host != null
      error_message = "Set esxi_ssh_host when ova.source_image_clone_type is esxi."
    }

    precondition {
      condition     = nonsensitive(var.esxi_ssh_password != null || var.esxi_ssh_private_key != null)
      error_message = "Set esxi_ssh_password or esxi_ssh_private_key when ova.source_image_clone_type is esxi."
    }
  }
}
