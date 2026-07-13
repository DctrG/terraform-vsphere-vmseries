resource "vsphere_virtual_machine" "this" {
  name             = var.name
  datacenter_id    = local.deploy_from_ova ? data.vsphere_datacenter.this.id : null
  datastore_id     = data.vsphere_datastore.vm.id
  resource_pool_id = local.resource_pool_id
  host_system_id   = local.host_system_id
  folder           = var.folder

  num_cpus             = coalesce(var.num_cpus, local.image_num_cpus)
  num_cores_per_socket = var.num_cores_per_socket
  memory               = coalesce(var.memory_mb, local.image_memory)
  guest_id             = local.image_guest_id
  firmware             = var.firmware != null ? var.firmware : (local.image_firmware != "" ? local.image_firmware : null)

  hardware_version = var.hardware_version != null ? var.hardware_version : (local.clone_with_esxi ? local.image_hardware_version : null)
  scsi_type        = local.image_scsi_type

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

  dynamic "vapp" {
    for_each = local.vapp_properties_enabled ? [1] : []

    content {
      properties = local.vapp_properties
    }
  }

  dynamic "network_interface" {
    for_each = local.network_interfaces_by_index

    content {
      network_id   = local.network_interface_ids[network_interface.key]
      adapter_type = network_interface.value.adapter_type
      ovf_mapping  = local.deploy_from_ova ? network_interface.value.ovf_mapping : null
    }
  }

  dynamic "disk" {
    for_each = local.source_image_disks

    content {
      label            = disk.value.label
      size             = disk.value.size
      eagerly_scrub    = disk.value.eagerly_scrub
      thin_provisioned = disk.value.thin_provisioned
      unit_number      = disk.value.unit_number
    }
  }

  dynamic "disk" {
    for_each = local.clone_with_esxi ? [1] : []

    content {
      label           = "disk0"
      attach          = true
      path            = local.esxi_disk_datastore_vm_path
      datastore_id    = data.vsphere_datastore.vm.id
      controller_type = "scsi"
      unit_number     = 0
    }
  }

  dynamic "clone" {
    for_each = local.clone_with_vcenter ? [1] : []

    content {
      template_uuid = data.vsphere_virtual_machine.source_image[0].id
      linked_clone  = var.ova.source_image_linked_clone
      timeout       = var.ova.source_image_clone_timeout
    }
  }

  dynamic "ovf_deploy" {
    for_each = local.deploy_from_ova ? [1] : []

    content {
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
  }

  dynamic "cdrom" {
    for_each = local.bootstrap_attach_iso ? [1] : []

    content {
      datastore_id = data.vsphere_datastore.bootstrap[0].id
      path         = local.bootstrap_datastore_path
    }
  }

  lifecycle {
    precondition {
      condition     = local.resource_pool_id != null
      error_message = "Set one of resource_pool_id, resource_pool_name, or cluster_name so the VM can be placed in a resource pool."
    }

    precondition {
      condition     = !local.deploy_from_ova || local.host_system_id != null
      error_message = "Set host_system_id or host_name when importing an OVA. The vSphere provider requires a target ESXi host for OVF/OVA deployment."
    }

    precondition {
      condition     = !local.clone_with_esxi || var.esxi_ssh_host != null
      error_message = "Set esxi_ssh_host when ova.source_image_clone_type is esxi."
    }
  }

  depends_on = [terraform_data.esxi_disk_clone, vsphere_file.bootstrap_iso]
}
