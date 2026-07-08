variable "vsphere_server" { type = string }
variable "vsphere_user" { type = string }
variable "vsphere_password" {
  type      = string
  sensitive = true
}
variable "vsphere_allow_unverified_ssl" {
  type    = bool
  default = true
}

variable "name" { type = string }
variable "datacenter" { type = string }
variable "cluster_name" { type = string }
variable "host_name" { type = string }
variable "datastore_name" { type = string }
variable "folder" {
  type    = string
  default = null
}
variable "ova_local_path" { type = string }

variable "network_interfaces" {
  type = list(object({
    ovf_label    = string
    network_name = string
    ovf_mapping  = optional(string)
    adapter_type = optional(string, "vmxnet3")
  }))
}

variable "mgmt_ip_address" { type = string }
variable "mgmt_default_gateway" { type = string }
variable "mgmt_netmask" { type = string }
variable "dns_primary" { type = string }
variable "dns_secondary" {
  type    = string
  default = null
}

variable "panorama_server" { type = string }
variable "template_stack" { type = string }
variable "device_group" { type = string }

variable "bootstrap_vm_auth_key" {
  type      = string
  sensitive = true
}

variable "bootstrap_license_authcodes" {
  type      = string
  sensitive = true
  default   = null
}
