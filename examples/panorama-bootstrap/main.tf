terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = ">= 2.14, < 3.0"
    }
  }
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = var.vsphere_allow_unverified_ssl
}

module "vmseries" {
  source = "../../"

  name               = var.name
  datacenter         = var.datacenter
  cluster_name       = var.cluster_name
  host_name          = var.host_name
  host_system_id     = var.host_system_id
  datastore_name     = var.datastore_name
  resource_pool_name = var.resource_pool_name
  resource_pool_id   = var.resource_pool_id
  folder             = var.folder

  ova = {
    local_path = var.ova_local_path
  }

  network_interfaces = var.network_interfaces
  vapp_properties    = var.vapp_properties

  bootstrap = {
    enabled                 = true
    create_iso              = true
    attach_iso              = true
    vapp_properties_enabled = var.bootstrap_vapp_properties_enabled
    datastore_path          = "vmseries-bootstrap/${var.name}/bootstrap.iso"

    management_type = var.mgmt_type
    ip_address      = var.mgmt_ip_address
    default_gateway = var.mgmt_default_gateway
    netmask         = var.mgmt_netmask
    hostname        = var.name

    panorama_server = var.panorama_server
    template_stack  = var.template_stack
    device_group    = var.device_group
    dns_primary     = var.dns_primary
    dns_secondary   = var.dns_secondary

    plugin_op_commands  = var.bootstrap_plugin_op_commands
    registration_pin_id = var.bootstrap_registration_pin_id
  }

  bootstrap_auth_key               = var.bootstrap_auth_key
  bootstrap_vapp_options           = var.bootstrap_vapp_options
  bootstrap_vm_auth_key            = var.bootstrap_vm_auth_key
  bootstrap_registration_pin_value = var.bootstrap_registration_pin_value
  bootstrap_license_authcodes      = var.bootstrap_license_authcodes
  bootstrap_files                  = var.bootstrap_files
}
