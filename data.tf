data "vsphere_datacenter" "this" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "this" {
  name          = var.cluster_name
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_resource_pool" "this" {
  count         = var.resource_pool_name == null ? 0 : 1
  name          = var.resource_pool_name
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_host" "this" {
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
  for_each      = local.network_interfaces_by_index
  name          = each.value.network_name
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_ovf_vm_template" "this" {
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
