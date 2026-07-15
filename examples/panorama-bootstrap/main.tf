terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = ">= 2.14, < 2.16"
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

  name                 = var.name
  datacenter           = var.datacenter
  cluster_name         = var.cluster_name
  host_name            = var.host_name
  host_system_id       = var.host_system_id
  datastore_name       = var.datastore_name
  resource_pool_name   = var.resource_pool_name
  resource_pool_id     = var.resource_pool_id
  folder               = var.folder
  hardware_version     = var.hardware_version
  num_cores_per_socket = var.num_cores_per_socket

  ova = {
    local_path                              = var.ova_local_path
    remote_url                              = var.ova_remote_url
    source_image_name                       = var.ova_source_image_name
    source_image_uuid                       = var.ova_source_image_uuid
    source_image_folder                     = var.ova_source_image_folder
    source_image_clone_type                 = var.ova_source_image_clone_type
    source_image_linked_clone               = var.ova_source_image_linked_clone
    source_image_clone_timeout              = var.ova_source_image_clone_timeout
    source_image_scsi_controller_scan_count = var.ova_source_image_scsi_controller_scan_count
    source_image_nvme_controller_scan_count = var.ova_source_image_nvme_controller_scan_count
    source_image_vmdk_path                  = var.ova_source_image_vmdk_path
    source_image_disk_datastore_path        = var.ova_source_image_disk_datastore_path
    source_image_disk_clone_type            = var.ova_source_image_disk_clone_type
    allow_unverified_ssl_cert               = var.ova_allow_unverified_ssl_cert
    deployment_option                       = var.ova_deployment_option
    ip_protocol                             = var.ova_ip_protocol
    ip_allocation_policy                    = var.ova_ip_allocation_policy
    enable_hidden_properties                = var.ova_enable_hidden_properties
  }

  network_interfaces = var.network_interfaces
  vapp_properties    = var.vapp_properties

  esxi_ssh_host        = var.esxi_ssh_host
  esxi_ssh_user        = var.esxi_ssh_user
  esxi_ssh_password    = var.esxi_ssh_password
  esxi_ssh_private_key = var.esxi_ssh_private_key
  esxi_ssh_port        = var.esxi_ssh_port
  esxi_ssh_timeout     = var.esxi_ssh_timeout

  bootstrap = {
    enabled                 = true
    create_iso              = true
    attach_iso              = true
    vapp_properties_enabled = var.bootstrap_vapp_properties_enabled
    datastore_path          = "${var.name}-bootstrap.iso"

    management_type = var.mgmt_type
    ip_address      = var.mgmt_ip_address
    default_gateway = var.mgmt_default_gateway
    netmask         = var.mgmt_netmask
    hostname        = coalesce(var.bootstrap_hostname, var.name)

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
