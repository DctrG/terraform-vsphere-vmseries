resource "vsphere_virtual_machine" "this" {
  name             = var.name
  datacenter_id    = data.vsphere_datacenter.this.id
  datastore_id     = data.vsphere_datastore.vm.id
  resource_pool_id = local.resource_pool_id
  host_system_id   = local.host_system_id
  folder           = var.folder

  num_cpus = coalesce(var.num_cpus, data.vsphere_ovf_vm_template.this.num_cpus)
  memory   = coalesce(var.memory_mb, data.vsphere_ovf_vm_template.this.memory)
  guest_id = data.vsphere_ovf_vm_template.this.guest_id
  firmware = var.firmware != null ? var.firmware : (data.vsphere_ovf_vm_template.this.firmware != "" ? data.vsphere_ovf_vm_template.this.firmware : null)

  scsi_type = data.vsphere_ovf_vm_template.this.scsi_type

  annotation             = var.annotation
  custom_attributes      = var.custom_attributes
  extra_config           = var.extra_config
  cpu_hot_add_enabled    = var.cpu_hot_add_enabled
  memory_hot_add_enabled = var.memory_hot_add_enabled
  force_power_off        = var.force_power_off
  poweron_timeout        = var.poweron_timeout
  shutdown_wait_timeout  = var.shutdown_wait_timeout
  storage_policy_id      = var.storage_policy_id
  tags                   = var.tags

  wait_for_guest_ip_timeout   = var.wait_for_guest_ip_timeout
  wait_for_guest_net_routable = var.wait_for_guest_net_routable
  wait_for_guest_net_timeout  = var.wait_for_guest_net_timeout

  dynamic "network_interface" {
    for_each = local.network_interfaces_by_index

    content {
      network_id   = local.network_interface_ids[network_interface.key]
      adapter_type = network_interface.value.adapter_type
      ovf_mapping  = network_interface.value.ovf_mapping
    }
  }

  ovf_deploy {
    local_ovf_path            = var.ova.local_path
    remote_ovf_url            = var.ova.remote_url
    allow_unverified_ssl_cert = var.ova.allow_unverified_ssl_cert
    deployment_option         = var.ova.deployment_option
    disk_provisioning         = var.disk_provisioning
    enable_hidden_properties  = var.ova.enable_hidden_properties
    ip_protocol               = var.ova.ip_protocol
    ip_allocation_policy      = var.ova.ip_allocation_policy
    ovf_network_map           = local.ovf_network_map
  }

  dynamic "cdrom" {
    for_each = local.bootstrap_attach_iso ? [1] : []

    content {
      datastore_id = data.vsphere_datastore.bootstrap[0].id
      path         = local.bootstrap_datastore_path
    }
  }

  depends_on = [vsphere_file.bootstrap_iso]
}
