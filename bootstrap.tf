resource "terraform_data" "bootstrap_dirs" {
  count = local.bootstrap_create_iso ? 1 : 0

  triggers_replace = [local.bootstrap_dir]

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      set -eu
      mkdir -p '${local.bootstrap_dir}/config' '${local.bootstrap_dir}/license' '${local.bootstrap_dir}/software' '${local.bootstrap_dir}/content' '${local.bootstrap_dir}/plugins'
    EOT
  }
}

resource "local_sensitive_file" "init_cfg" {
  count = local.bootstrap_create_iso ? 1 : 0

  filename             = "${local.bootstrap_dir}/config/init-cfg.txt"
  content              = local.init_cfg_content
  file_permission      = "0600"
  directory_permission = "0700"

  depends_on = [terraform_data.bootstrap_dirs]
}

resource "local_sensitive_file" "license_authcodes" {
  count = local.bootstrap_create_iso && var.bootstrap_license_authcodes != null ? 1 : 0

  filename             = "${local.bootstrap_dir}/license/authcodes"
  content              = var.bootstrap_license_authcodes
  file_permission      = "0600"
  directory_permission = "0700"

  depends_on = [terraform_data.bootstrap_dirs]
}

resource "local_sensitive_file" "bootstrap_xml" {
  count = local.bootstrap_create_iso && var.bootstrap_xml != null ? 1 : 0

  filename             = "${local.bootstrap_dir}/config/bootstrap.xml"
  content              = var.bootstrap_xml
  file_permission      = "0600"
  directory_permission = "0700"

  depends_on = [terraform_data.bootstrap_dirs]
}

resource "local_sensitive_file" "bootstrap_files" {
  for_each = local.bootstrap_create_iso ? toset(local.bootstrap_file_paths) : toset([])

  filename             = "${local.bootstrap_dir}/${each.key}"
  content              = var.bootstrap_files[each.key].content
  content_base64       = var.bootstrap_files[each.key].content_base64
  source               = var.bootstrap_files[each.key].source
  file_permission      = var.bootstrap_files[each.key].file_permission
  directory_permission = "0700"

  depends_on = [terraform_data.bootstrap_dirs]
}

resource "terraform_data" "bootstrap_iso" {
  count = local.bootstrap_create_iso ? 1 : 0

  triggers_replace = [
    local.bootstrap_dir,
    local.bootstrap_iso_local_path,
    nonsensitive(sha256(local.init_cfg_content)),
    nonsensitive(sha256(var.bootstrap_license_authcodes == null ? "" : var.bootstrap_license_authcodes)),
    nonsensitive(sha256(var.bootstrap_xml == null ? "" : var.bootstrap_xml)),
    local.bootstrap_files_fingerprint
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      set -eu
      SRC='${local.bootstrap_dir}'
      ISO='${local.bootstrap_iso_local_path}'
      mkdir -p "$(dirname "$ISO")"
      rm -f "$ISO"

      if command -v genisoimage >/dev/null 2>&1; then
        genisoimage -quiet -J -R -V bootstrap -o "$ISO" "$SRC"
      elif command -v mkisofs >/dev/null 2>&1; then
        mkisofs -quiet -J -R -V bootstrap -o "$ISO" "$SRC"
      elif command -v xorrisofs >/dev/null 2>&1; then
        xorrisofs -quiet -J -R -V bootstrap -o "$ISO" "$SRC"
      elif command -v hdiutil >/dev/null 2>&1; then
        hdiutil makehybrid -iso -joliet -default-volume-name bootstrap -o "$ISO" "$SRC" >/dev/null
      else
        echo "No ISO builder found. Install genisoimage, mkisofs, xorrisofs, or use macOS hdiutil." >&2
        exit 1
      fi
    EOT
  }

  depends_on = [
    local_sensitive_file.init_cfg,
    local_sensitive_file.license_authcodes,
    local_sensitive_file.bootstrap_xml,
    local_sensitive_file.bootstrap_files
  ]
}

resource "vsphere_file" "bootstrap_iso" {
  count = local.bootstrap_upload_iso ? 1 : 0

  datacenter         = var.datacenter
  datastore          = local.bootstrap_datastore_name
  source_file        = local.bootstrap_iso_local_path
  destination_file   = local.bootstrap_datastore_path
  create_directories = var.bootstrap.create_datastore_directories

  depends_on = [terraform_data.bootstrap_iso]
}
