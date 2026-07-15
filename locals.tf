locals {
  deploy_from_source_image = var.ova.source_image_name != null || var.ova.source_image_uuid != null
  deploy_from_ova          = !local.deploy_from_source_image
  source_image_clone_type  = local.deploy_from_source_image ? var.ova.source_image_clone_type : null
  clone_with_vcenter       = local.deploy_from_source_image && local.source_image_clone_type == "vcenter"
  clone_with_esxi          = local.deploy_from_source_image && local.source_image_clone_type == "esxi"

  image_num_cpus = try(coalesce(
    try(data.vsphere_virtual_machine.source_image[0].num_cpus, null),
    try(data.vsphere_ovf_vm_template.this[0].num_cpus, null),
    2
  ), 2)
  image_memory = try(coalesce(
    try(data.vsphere_virtual_machine.source_image[0].memory, null),
    try(data.vsphere_ovf_vm_template.this[0].memory, null),
    5632
  ), 5632)
  image_guest_id = try(coalesce(
    try(data.vsphere_virtual_machine.source_image[0].guest_id, null),
    try(data.vsphere_ovf_vm_template.this[0].guest_id, null),
    "otherLinux64Guest"
  ), "otherLinux64Guest")
  image_firmware = try(coalesce(
    try(data.vsphere_virtual_machine.source_image[0].firmware, null),
    try(data.vsphere_ovf_vm_template.this[0].firmware, null)
  ), "")
  image_hardware_version = try(data.vsphere_virtual_machine.source_image[0].hardware_version, null)
  image_scsi_type = try(coalesce(
    try(data.vsphere_virtual_machine.source_image[0].scsi_type, null),
    try(data.vsphere_ovf_vm_template.this[0].scsi_type, null),
    "lsilogic"
  ), "lsilogic")
  source_image_disks = local.clone_with_vcenter ? try(data.vsphere_virtual_machine.source_image[0].disks, []) : []
  esxi_disk_datastore_path = local.clone_with_esxi ? coalesce(
    var.ova.source_image_disk_datastore_path,
    "${var.name}-disk/${var.name}.vmdk"
  ) : null
  esxi_disk_datastore_vm_path = local.clone_with_esxi ? "[${var.datastore_name}] ${local.esxi_disk_datastore_path}" : null
  esxi_disk_vmfs_path         = local.clone_with_esxi ? "/vmfs/volumes/${var.datastore_name}/${local.esxi_disk_datastore_path}" : null
  esxi_disk_vmfs_dir          = local.clone_with_esxi ? dirname(local.esxi_disk_vmfs_path) : null
  esxi_source_vmdk_shell      = local.clone_with_esxi ? "'${replace(var.ova.source_image_vmdk_path, "'", "'\"'\"'")}'" : null
  esxi_disk_vmfs_path_shell   = local.clone_with_esxi ? "'${replace(local.esxi_disk_vmfs_path, "'", "'\"'\"'")}'" : null
  esxi_disk_vmfs_dir_shell    = local.clone_with_esxi ? "'${replace(local.esxi_disk_vmfs_dir, "'", "'\"'\"'")}'" : null
  esxi_disk_clone_type_shell  = local.clone_with_esxi ? "'${replace(var.ova.source_image_disk_clone_type, "'", "'\"'\"'")}'" : null

  resource_pool_id = try(coalesce(
    var.resource_pool_id,
    try(data.vsphere_resource_pool.this[0].id, null),
    try(data.vsphere_compute_cluster.this[0].resource_pool_id, null)
  ), null)
  host_system_id = try(coalesce(
    var.host_system_id,
    try(data.vsphere_host.this[0].id, null)
  ), null)

  network_interfaces_by_index = {
    for index, nic in var.network_interfaces :
    tostring(index) => nic
  }

  network_interfaces_by_name = {
    for index, nic in var.network_interfaces :
    tostring(index) => nic
    if nic.network_id == null
  }

  network_interface_ids = {
    for index, nic in var.network_interfaces :
    tostring(index) => nic.network_id != null ? nic.network_id : data.vsphere_network.interface[tostring(index)].id
  }

  ovf_network_map = {
    for ovf_label in distinct([for nic in var.network_interfaces : nic.ovf_label]) :
    ovf_label => local.network_interface_ids[tostring(index([for nic in var.network_interfaces : nic.ovf_label], ovf_label))]
  }

  bootstrap_enabled        = var.bootstrap.enabled
  bootstrap_create_iso     = local.bootstrap_enabled && var.bootstrap.create_iso
  bootstrap_attach_iso     = local.bootstrap_enabled && var.bootstrap.attach_iso
  bootstrap_vapp_enabled   = local.bootstrap_enabled && var.bootstrap.vapp_properties_enabled
  bootstrap_datastore_name = coalesce(var.bootstrap.datastore_name, var.datastore_name)
  bootstrap_datastore_path = coalesce(var.bootstrap.datastore_path, "${var.name}-bootstrap.iso")
  bootstrap_dir            = coalesce(var.bootstrap.work_dir, "${path.root}/.terraform/vmseries-bootstrap/${var.name}")
  bootstrap_iso_local_path = coalesce(var.bootstrap.local_iso_path, "${local.bootstrap_dir}/bootstrap.iso")
  bootstrap_upload_iso     = local.bootstrap_attach_iso && (local.bootstrap_create_iso || var.bootstrap.local_iso_path != null)
  bootstrap_management_ip  = var.bootstrap.management_type == "static" ? var.bootstrap.ip_address : null
  bootstrap_file_paths     = sort(keys(nonsensitive(var.bootstrap_files)))
  bootstrap_files_fingerprint = sha256(jsonencode({
    for path in local.bootstrap_file_paths : path => {
      content_sha256        = var.bootstrap_files[path].content == null ? null : sha256(var.bootstrap_files[path].content)
      content_base64_sha256 = var.bootstrap_files[path].content_base64 == null ? null : sha256(var.bootstrap_files[path].content_base64)
      source_sha256         = var.bootstrap_files[path].source == null ? null : filesha256(nonsensitive(var.bootstrap_files[path].source))
      file_permission       = var.bootstrap_files[path].file_permission
    }
  }))

  init_cfg_ordered_lines = compact([
    "type=${var.bootstrap.management_type}",
    var.bootstrap.ip_address != null ? "ip-address=${var.bootstrap.ip_address}" : null,
    var.bootstrap.default_gateway != null ? "default-gateway=${var.bootstrap.default_gateway}" : null,
    var.bootstrap.netmask != null ? "netmask=${var.bootstrap.netmask}" : null,
    var.bootstrap.ipv6_address != null ? "ipv6-address=${var.bootstrap.ipv6_address}" : null,
    var.bootstrap.ipv6_default_gateway != null ? "ipv6-default-gateway=${var.bootstrap.ipv6_default_gateway}" : null,
    var.bootstrap.hostname != null ? "hostname=${var.bootstrap.hostname}" : null,
    var.bootstrap.panorama_server != null ? "panorama-server=${var.bootstrap.panorama_server}" : null,
    var.bootstrap.panorama_server_2 != null ? "panorama-server-2=${var.bootstrap.panorama_server_2}" : null,
    var.bootstrap.template_stack != null ? "tplname=${var.bootstrap.template_stack}" : null,
    var.bootstrap.device_group != null ? "dgname=${var.bootstrap.device_group}" : null,
    var.bootstrap.dns_primary != null ? "dns-primary=${var.bootstrap.dns_primary}" : null,
    var.bootstrap.dns_secondary != null ? "dns-secondary=${var.bootstrap.dns_secondary}" : null,
    var.bootstrap_auth_key != null ? "auth-key=${var.bootstrap_auth_key}" : null,
    var.bootstrap_vm_auth_key != null ? "vm-auth-key=${var.bootstrap_vm_auth_key}" : null,
    var.bootstrap.op_command_modes != null ? "op-command-modes=${var.bootstrap.op_command_modes}" : null,
    var.bootstrap.op_cmd_dpdk_pkt_io != null ? "op-cmd-dpdk-pkt-io=${var.bootstrap.op_cmd_dpdk_pkt_io}" : null,
    var.bootstrap.plugin_op_commands != null ? "plugin-op-commands=${var.bootstrap.plugin_op_commands}" : null,
    var.bootstrap.dhcp_send_hostname != null ? "dhcp-send-hostname=${var.bootstrap.dhcp_send_hostname}" : null,
    var.bootstrap.dhcp_send_client_id != null ? "dhcp-send-client-id=${var.bootstrap.dhcp_send_client_id}" : null,
    var.bootstrap.dhcp_accept_server_hostname != null ? "dhcp-accept-server-hostname=${var.bootstrap.dhcp_accept_server_hostname}" : null,
    var.bootstrap.dhcp_accept_server_domain != null ? "dhcp-accept-server-domain=${var.bootstrap.dhcp_accept_server_domain}" : null,
    var.bootstrap.registration_pin_id != null ? "vm-series-auto-registration-pin-id=${var.bootstrap.registration_pin_id}" : null,
    var.bootstrap_registration_pin_value != null ? "vm-series-auto-registration-pin-value=${var.bootstrap_registration_pin_value}" : null
  ])

  init_cfg_additional_lines = [
    for key in sort(keys(var.bootstrap.additional_parameters)) :
    "${key}=${var.bootstrap.additional_parameters[key]}"
    if var.bootstrap.additional_parameters[key] != null
  ]

  init_cfg_content = "${join("\n", concat(local.init_cfg_ordered_lines, local.init_cfg_additional_lines))}\n"

  bootstrap_vapp_raw_properties = local.bootstrap_vapp_enabled ? {
    "guestinfo.pa_vm.hostname"                              = var.bootstrap.hostname
    "guestinfo.pa_vm.type"                                  = var.bootstrap.management_type
    "guestinfo.pa_vm.ip-address"                            = var.bootstrap.ip_address
    "guestinfo.pa_vm.netmask"                               = var.bootstrap.netmask
    "guestinfo.pa_vm.default-gateway"                       = var.bootstrap.default_gateway
    "guestinfo.pa_vm.ipv6-address"                          = var.bootstrap.ipv6_address
    "guestinfo.pa_vm.ipv6-default-gateway"                  = var.bootstrap.ipv6_default_gateway
    "guestinfo.pa_vm.dns-primary"                           = var.bootstrap.dns_primary
    "guestinfo.pa_vm.dns-secondary"                         = var.bootstrap.dns_secondary
    "guestinfo.pa_vm.panorama-server"                       = var.bootstrap.panorama_server
    "guestinfo.pa_vm.panorama-server-2"                     = var.bootstrap.panorama_server_2
    "guestinfo.pa_vm.tplname"                               = var.bootstrap.template_stack
    "guestinfo.pa_vm.dgname"                                = var.bootstrap.device_group
    "guestinfo.pa_vm.auth-key"                              = var.bootstrap_auth_key
    "guestinfo.pa_vm.vm-auth-key"                           = var.bootstrap_vm_auth_key
    "guestinfo.pa_vm.authcodes"                             = var.bootstrap_license_authcodes
    "guestinfo.pa_vm.vm-series-auto-registration-pin-id"    = var.bootstrap.registration_pin_id
    "guestinfo.pa_vm.vm-series-auto-registration-pin-value" = var.bootstrap_registration_pin_value
    "guestinfo.pa_vm.options"                               = var.bootstrap_vapp_options
  } : {}

  bootstrap_vapp_properties = {
    for key, value in local.bootstrap_vapp_raw_properties :
    key => value
    if value != null
  }

  vapp_properties_enabled = local.bootstrap_vapp_enabled || length(nonsensitive(var.vapp_properties)) > 0
  vapp_properties         = merge(local.bootstrap_vapp_properties, var.vapp_properties)
}
