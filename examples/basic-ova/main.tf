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

  name           = var.name
  datacenter     = var.datacenter
  cluster_name   = var.cluster_name
  host_name      = var.host_name
  datastore_name = var.datastore_name
  folder         = var.folder

  ova = {
    local_path = var.ova_local_path
  }

  network_interfaces = var.network_interfaces
}
