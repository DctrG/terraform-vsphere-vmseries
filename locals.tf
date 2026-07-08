locals {
  resource_pool_id = var.resource_pool_name == null ? data.vsphere_compute_cluster.this.resource_pool_id : data.vsphere_resource_pool.this[0].id
  host_system_id   = data.vsphere_host.this.id

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
  bootstrap_datastore_name = coalesce(var.bootstrap.datastore_name, var.datastore_name)
  bootstrap_datastore_path = coalesce(var.bootstrap.datastore_path, "vmseries-bootstrap/${var.name}/bootstrap.iso")
  bootstrap_dir            = coalesce(var.bootstrap.work_dir, "${path.root}/.terraform/vmseries-bootstrap/${var.name}")
  bootstrap_iso_local_path = coalesce(var.bootstrap.local_iso_path, "${local.bootstrap_dir}/bootstrap.iso")
  bootstrap_upload_iso     = local.bootstrap_attach_iso && (local.bootstrap_create_iso || var.bootstrap.local_iso_path != null)
  bootstrap_management_ip  = var.bootstrap.management_type == "static" ? var.bootstrap.ip_address : null

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
    var.bootstrap.op_command_modes != null ? "op-command-modes=${var.bootstrap.op_command_modes}" : null,
    var.bootstrap.op_cmd_dpdk_pkt_io != null ? "op-cmd-dpdk-pkt-io=${var.bootstrap.op_cmd_dpdk_pkt_io}" : null,
    var.bootstrap.plugin_op_commands != null ? "plugin-op-commands=${var.bootstrap.plugin_op_commands}" : null,
    var.bootstrap.dhcp_send_hostname != null ? "dhcp-send-hostname=${var.bootstrap.dhcp_send_hostname}" : null,
    var.bootstrap.dhcp_send_client_id != null ? "dhcp-send-client-id=${var.bootstrap.dhcp_send_client_id}" : null,
    var.bootstrap.dhcp_accept_server_hostname != null ? "dhcp-accept-server-hostname=${var.bootstrap.dhcp_accept_server_hostname}" : null,
    var.bootstrap.dhcp_accept_server_domain != null ? "dhcp-accept-server-domain=${var.bootstrap.dhcp_accept_server_domain}" : null,
    var.bootstrap.registration_pin_id != null ? "vm-series-auto-registration-pin-id=${var.bootstrap.registration_pin_id}" : null,
    var.bootstrap_registration_pin_value != null ? "vm-series-auto-registration-pin-value=${var.bootstrap_registration_pin_value}" : null,
    var.bootstrap_vm_auth_key != null ? "vm-auth-key=${var.bootstrap_vm_auth_key}" : null
  ])

  init_cfg_additional_lines = [
    for key in sort(keys(var.bootstrap.additional_parameters)) :
    "${key}=${var.bootstrap.additional_parameters[key]}"
    if var.bootstrap.additional_parameters[key] != null
  ]

  init_cfg_content = "${join("\n", concat(local.init_cfg_ordered_lines, local.init_cfg_additional_lines))}\n"
}
