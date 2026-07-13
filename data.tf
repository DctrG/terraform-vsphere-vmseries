data "vsphere_datacenter" "this" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "this" {
  count         = var.cluster_name == null ? 0 : 1
  name          = var.cluster_name
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_resource_pool" "this" {
  count         = var.resource_pool_id == null && var.resource_pool_name != null ? 1 : 0
  name          = var.resource_pool_name
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_host" "this" {
  count         = var.host_system_id == null && var.host_name != null ? 1 : 0
  name          = var.host_name
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_datastore" "vm" {
  name          = var.datastore_name
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_datastore" "bootstrap" {
  count         = local.bootstrap_attach_iso ? 1 : 0
  name          = local.bootstrap_datastore_name
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_network" "interface" {
  for_each      = local.network_interfaces_by_name
  name          = each.value.network_name
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_virtual_machine" "source_image" {
  count         = local.deploy_from_source_image ? 1 : 0
  name          = var.ova.source_image_name
  uuid          = var.ova.source_image_uuid
  folder        = var.ova.source_image_folder
  datacenter_id = data.vsphere_datacenter.this.id

  scsi_controller_scan_count = var.ova.source_image_scsi_controller_scan_count
  nvme_controller_scan_count = var.ova.source_image_nvme_controller_scan_count
}

data "vsphere_ovf_vm_template" "this" {
  count                     = local.deploy_from_ova && local.host_system_id != null && local.resource_pool_id != null ? 1 : 0
  name                      = var.name
  datastore_id              = data.vsphere_datastore.vm.id
  resource_pool_id          = local.resource_pool_id
  host_system_id            = local.host_system_id
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
