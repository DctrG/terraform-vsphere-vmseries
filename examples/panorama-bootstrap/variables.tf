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
variable "cluster_name" {
  type    = string
  default = null
}
variable "host_name" {
  type    = string
  default = null
}
variable "host_system_id" {
  type    = string
  default = null
}
variable "datastore_name" { type = string }
variable "resource_pool_name" {
  type    = string
  default = null
}
variable "resource_pool_id" {
  type    = string
  default = null
}
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

variable "vapp_properties" {
  type      = map(string)
  sensitive = true
  default   = {}
}

variable "mgmt_type" {
  type    = string
  default = "static"

  validation {
    condition     = contains(["static", "dhcp-client"], var.mgmt_type)
    error_message = "mgmt_type must be static or dhcp-client."
  }
}
variable "mgmt_ip_address" {
  type    = string
  default = null
}
variable "mgmt_default_gateway" {
  type    = string
  default = null
}
variable "mgmt_netmask" {
  type    = string
  default = null
}
variable "dns_primary" {
  type    = string
  default = null
}
variable "dns_secondary" {
  type    = string
  default = null
}

variable "panorama_server" { type = string }
variable "template_stack" { type = string }
variable "device_group" { type = string }

variable "bootstrap_vm_auth_key" {
  description = "Panorama VM auth key rendered as vm-auth-key for Panorama registration."
  type        = string
  sensitive   = true
  default     = null
}

variable "bootstrap_auth_key" {
  description = "Optional plugin bootstrap value rendered as auth-key. Not a replacement for bootstrap_vm_auth_key."
  type        = string
  sensitive   = true
  default     = null
}

variable "bootstrap_vapp_properties_enabled" {
  type    = bool
  default = false
}

variable "bootstrap_vapp_options" {
  type      = string
  sensitive = true
  default   = null
}

variable "bootstrap_plugin_op_commands" {
  type    = string
  default = null
}

variable "bootstrap_registration_pin_id" {
  type    = string
  default = null
}

variable "bootstrap_registration_pin_value" {
  type      = string
  sensitive = true
  default   = null
}

variable "bootstrap_license_authcodes" {
  type      = string
  sensitive = true
  default   = null
}

variable "bootstrap_files" {
  type = map(object({
    content         = optional(string)
    content_base64  = optional(string)
    source          = optional(string)
    file_permission = optional(string, "0600")
  }))
  sensitive = true
  default   = {}
}
