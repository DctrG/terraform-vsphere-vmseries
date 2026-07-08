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
    network_name = optional(string)
    network_id   = optional(string)
    ovf_mapping  = optional(string)
    adapter_type = optional(string, "vmxnet3")
  }))
}
