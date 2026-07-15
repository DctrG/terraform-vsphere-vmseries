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
variable "bootstrap_hostname" {
  description = "Optional PAN-OS hostname override when the vSphere VM name must use a distinct datastore path."
  type        = string
  default     = null

  validation {
    condition     = var.bootstrap_hostname == null ? true : length(trimspace(var.bootstrap_hostname)) > 0
    error_message = "bootstrap_hostname must not be empty when set."
  }
}
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
variable "hardware_version" {
  description = "Optional VM hardware version override. Usually null; ESXi source-image mode inherits this from the golden image when available."
  type        = number
  default     = null
}
variable "num_cores_per_socket" {
  description = "Optional cores-per-socket override."
  type        = number
  default     = null
}
variable "ova_local_path" {
  description = "Optional local OVA path. Use only for first-time OVA import; repeated deployments should use ova_source_image_name or ova_source_image_uuid."
  type        = string
  default     = null
}

variable "ova_remote_url" {
  description = "Optional remote OVA/OVF URL. Use only for first-time OVA import; repeated deployments should use ova_source_image_name or ova_source_image_uuid."
  type        = string
  default     = null
}

variable "ova_source_image_name" {
  description = "Optional vSphere VM/template name to clone from for repeated deployments."
  type        = string
  default     = null
}

variable "ova_source_image_uuid" {
  description = "Optional vSphere VM/template UUID to clone from for repeated deployments."
  type        = string
  default     = null
}

variable "ova_source_image_folder" {
  description = "Optional vSphere folder containing the source image VM/template."
  type        = string
  default     = null
}

variable "ova_source_image_clone_type" {
  description = "How to clone from a source image. Use vcenter for vCenter VM/template clone, or esxi for SSH-assisted VMDK copy on standalone ESXi."
  type        = string
  default     = "vcenter"

  validation {
    condition     = contains(["vcenter", "esxi"], var.ova_source_image_clone_type)
    error_message = "ova_source_image_clone_type must be either vcenter or esxi."
  }
}

variable "ova_source_image_linked_clone" {
  description = "Whether to create linked clones from the source image."
  type        = bool
  default     = false
}

variable "ova_source_image_clone_timeout" {
  description = "Optional timeout, in minutes, for source image clone operations."
  type        = number
  default     = null
}

variable "ova_source_image_scsi_controller_scan_count" {
  description = "Number of SCSI controllers to scan on the source image."
  type        = number
  default     = 1
}

variable "ova_source_image_nvme_controller_scan_count" {
  description = "Number of NVMe controllers to scan on the source image."
  type        = number
  default     = 1
}

variable "ova_source_image_vmdk_path" {
  description = "Absolute VMFS path to the golden image VMDK descriptor when ova_source_image_clone_type is esxi."
  type        = string
  default     = null
}

variable "ova_source_image_disk_datastore_path" {
  description = "Optional destination datastore path for the per-VM cloned VMDK when ova_source_image_clone_type is esxi."
  type        = string
  default     = null
}

variable "ova_source_image_disk_clone_type" {
  description = "vmkfstools disk clone type when ova_source_image_clone_type is esxi."
  type        = string
  default     = "thin"

  validation {
    condition     = contains(["thin", "zeroedthick", "eagerzeroedthick"], var.ova_source_image_disk_clone_type)
    error_message = "ova_source_image_disk_clone_type must be one of: thin, zeroedthick, eagerzeroedthick."
  }
}

variable "esxi_ssh_host" {
  description = "Optional ESXi SSH host used only when ova_source_image_clone_type is esxi."
  type        = string
  default     = null
}

variable "esxi_ssh_user" {
  description = "ESXi SSH user used only when ova_source_image_clone_type is esxi."
  type        = string
  default     = "root"
}

variable "esxi_ssh_password" {
  description = "Optional ESXi SSH password used only when ova_source_image_clone_type is esxi."
  type        = string
  sensitive   = true
  default     = null
}

variable "esxi_ssh_private_key" {
  description = "Optional ESXi SSH private key contents used only when ova_source_image_clone_type is esxi."
  type        = string
  sensitive   = true
  default     = null
}

variable "esxi_ssh_port" {
  description = "ESXi SSH port used only when ova_source_image_clone_type is esxi."
  type        = number
  default     = 22
}

variable "esxi_ssh_timeout" {
  description = "ESXi SSH connection timeout used only when ova_source_image_clone_type is esxi."
  type        = string
  default     = "10m"
}

variable "ova_allow_unverified_ssl_cert" {
  description = "Allow unverified SSL certificates for remote OVA/OVF import."
  type        = bool
  default     = false
}

variable "ova_deployment_option" {
  description = "Optional OVF deployment option for OVA/OVF import."
  type        = string
  default     = null
}

variable "ova_ip_protocol" {
  description = "OVF IP protocol for OVA/OVF import."
  type        = string
  default     = "IPV4"
}

variable "ova_ip_allocation_policy" {
  description = "OVF IP allocation policy for OVA/OVF import."
  type        = string
  default     = "STATIC_MANUAL"
}

variable "ova_enable_hidden_properties" {
  description = "Enable hidden OVF properties during OVA/OVF import."
  type        = bool
  default     = false
}

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

variable "panorama_server" {
  description = "Panorama address reachable from the firewall management interface; use the public/NAT address when Panorama's private address is not reachable."
  type        = string
}
variable "template_stack" { type = string }
variable "device_group" { type = string }

variable "bootstrap_vm_auth_key" {
  description = "Optional Panorama VM auth key rendered as vm-auth-key for workflows that explicitly require that key."
  type        = string
  sensitive   = true
  default     = null
}

variable "bootstrap_auth_key" {
  description = "Optional Panorama/plugin bootstrap value rendered as auth-key. Use this for Software Firewall License plugin onboarding when Panorama returns an auth-key."
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
