variable "name" {
  description = "Name of the VM-Series virtual machine in vCenter."
  type        = string

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty."
  }
}

variable "datacenter" {
  description = "vSphere datacenter name."
  type        = string
}

variable "cluster_name" {
  description = "vSphere compute cluster name. Used to resolve the default resource pool."
  type        = string
}

variable "host_name" {
  description = "ESXi host name to target for OVF/OVA deployment. OVA deployment requires direct host selection."
  type        = string
}

variable "datastore_name" {
  description = "Datastore for the VM configuration and disks."
  type        = string
}

variable "resource_pool_name" {
  description = "Optional resource pool name. If null, the cluster root resource pool is used."
  type        = string
  default     = null
}

variable "folder" {
  description = "Optional vSphere VM folder path."
  type        = string
  default     = null
}

variable "ova" {
  description = <<-EOT
    VM-Series OVA source and OVF deployment options. Set exactly one of local_path or remote_url.
  EOT

  type = object({
    local_path                = optional(string)
    remote_url                = optional(string)
    allow_unverified_ssl_cert = optional(bool, false)
    deployment_option         = optional(string)
    ip_protocol               = optional(string, "IPV4")
    ip_allocation_policy      = optional(string, "STATIC_MANUAL")
    enable_hidden_properties  = optional(bool, false)
  })

  validation {
    condition = (
      (try(var.ova.local_path, null) != null && try(var.ova.remote_url, null) == null) ||
      (try(var.ova.local_path, null) == null && try(var.ova.remote_url, null) != null)
    )
    error_message = "Set exactly one of ova.local_path or ova.remote_url."
  }
}

variable "network_interfaces" {
  description = <<-EOT
    Ordered VM-Series interface mappings to vSphere port groups.

    ovf_label is the OVF network name used during import. Some VM-Series OVAs expose one shared label such as "VM Network"
    for every adapter. In that case, repeat ovf_label and set ovf_mapping to the adapter name from the OVF, such as
    "Ethernet 1", "Ethernet 2", and "Ethernet 3".
  EOT

  type = list(object({
    ovf_label    = string
    network_name = string
    ovf_mapping  = optional(string)
    adapter_type = optional(string, "vmxnet3")
  }))

  validation {
    condition     = length(var.network_interfaces) >= 2
    error_message = "At least two interfaces are required: management plus at least one dataplane interface."
  }

  validation {
    condition = alltrue([
      for nic in var.network_interfaces :
      length(trimspace(nic.ovf_label)) > 0 &&
      length(trimspace(nic.network_name)) > 0 &&
      (nic.ovf_mapping == null || length(trimspace(nic.ovf_mapping)) > 0)
    ])
    error_message = "network_interfaces entries must include non-empty ovf_label and network_name values; ovf_mapping must be non-empty when set."
  }

  validation {
    condition = (
      length(distinct([for nic in var.network_interfaces : nic.ovf_mapping if nic.ovf_mapping != null])) ==
      length([for nic in var.network_interfaces : nic.ovf_mapping if nic.ovf_mapping != null])
    )
    error_message = "network_interfaces.ovf_mapping values must be unique when set."
  }
}

variable "disk_provisioning" {
  description = "Disk provisioning mode for the OVA deployment."
  type        = string
  default     = "thin"

  validation {
    condition     = contains(["thin", "thick", "eagerZeroedThick"], var.disk_provisioning)
    error_message = "disk_provisioning must be one of: thin, thick, eagerZeroedThick."
  }
}

variable "num_cpus" {
  description = "Optional CPU override. If null, the OVA default is used."
  type        = number
  default     = null
}

variable "memory_mb" {
  description = "Optional memory override in MB. If null, the OVA default is used."
  type        = number
  default     = null
}

variable "firmware" {
  description = "Optional firmware override. If null, the OVA default is used."
  type        = string
  default     = null

  validation {
    condition     = var.firmware == null ? true : contains(["bios", "efi"], var.firmware)
    error_message = "firmware must be bios, efi, or null."
  }
}

variable "annotation" {
  description = "Optional vSphere annotation for the VM."
  type        = string
  default     = "Managed by Terraform module terraform-vsphere-vmseries."
}

variable "extra_config" {
  description = "Additional VMX extra_config key/value pairs."
  type        = map(string)
  default     = {}
}

variable "cpu_hot_add_enabled" {
  description = "Enable CPU hot-add."
  type        = bool
  default     = false
}

variable "memory_hot_add_enabled" {
  description = "Enable memory hot-add."
  type        = bool
  default     = false
}

variable "wait_for_guest_ip_timeout" {
  description = "Timeout in minutes to wait for a guest IP. VM-Series does not normally report this reliably before bootstrap, so the default is 0."
  type        = number
  default     = 0
}

variable "wait_for_guest_net_timeout" {
  description = "Timeout in minutes to wait for guest networking. VM-Series does not normally report this reliably before bootstrap, so the default is 0."
  type        = number
  default     = 0
}

variable "bootstrap" {
  description = <<-EOT
    Optional VM-Series bootstrap ISO generation, upload, and CD-ROM attachment settings.

    Modes:
    - enabled=false: no bootstrap CD-ROM is attached.
    - enabled=true, create_iso=true: module renders init-cfg.txt, optionally authcodes/bootstrap.xml, builds an ISO locally, uploads it with vsphere_file, and attaches it.
    - enabled=true, create_iso=false, local_iso_path set: module uploads the supplied local ISO and attaches it.
    - enabled=true, create_iso=false, local_iso_path null: module assumes datastore_path already exists and attaches it.
  EOT

  type = object({
    enabled                     = optional(bool, false)
    create_iso                  = optional(bool, true)
    attach_iso                  = optional(bool, true)
    work_dir                    = optional(string)
    local_iso_path              = optional(string)
    datastore_name              = optional(string)
    datastore_path              = optional(string)
    management_type             = optional(string, "static")
    ip_address                  = optional(string)
    default_gateway             = optional(string)
    netmask                     = optional(string)
    ipv6_address                = optional(string)
    ipv6_default_gateway        = optional(string)
    hostname                    = optional(string)
    panorama_server             = optional(string)
    panorama_server_2           = optional(string)
    template_stack              = optional(string)
    device_group                = optional(string)
    dns_primary                 = optional(string)
    dns_secondary               = optional(string)
    op_command_modes            = optional(string)
    op_cmd_dpdk_pkt_io          = optional(string)
    plugin_op_commands          = optional(string)
    dhcp_send_hostname          = optional(string)
    dhcp_send_client_id         = optional(string)
    dhcp_accept_server_hostname = optional(string)
    dhcp_accept_server_domain   = optional(string)
    registration_pin_id         = optional(string)
    additional_parameters       = optional(map(string), {})
  })

  default = {
    enabled = false
  }

  validation {
    condition     = contains(["static", "dhcp-client"], var.bootstrap.management_type)
    error_message = "bootstrap.management_type must be static or dhcp-client."
  }

  validation {
    condition = (
      !var.bootstrap.enabled ||
      var.bootstrap.management_type == "dhcp-client" ||
      (var.bootstrap.ip_address != null && var.bootstrap.default_gateway != null && var.bootstrap.netmask != null)
    )
    error_message = "For static bootstrap management, ip_address, default_gateway, and netmask are required."
  }

  validation {
    condition = (
      !var.bootstrap.enabled ||
      !var.bootstrap.attach_iso ||
      var.bootstrap.datastore_path != null ||
      var.bootstrap.create_iso ||
      var.bootstrap.local_iso_path != null
    )
    error_message = "When attaching a pre-existing datastore ISO, set bootstrap.datastore_path."
  }
}

variable "bootstrap_vm_auth_key" {
  description = "Optional Panorama VM auth key to include in /config/init-cfg.txt."
  type        = string
  default     = null
  sensitive   = true
}

variable "bootstrap_registration_pin_value" {
  description = "Optional VM-Series auto-registration PIN value to include in /config/init-cfg.txt."
  type        = string
  default     = null
  sensitive   = true
}

variable "bootstrap_license_authcodes" {
  description = "Optional content for /license/authcodes. Put one or more VM-Series auth codes as expected by PAN-OS."
  type        = string
  default     = null
  sensitive   = true
}

variable "bootstrap_xml" {
  description = "Optional full bootstrap.xml configuration content. Most Panorama-managed deployments should leave this null."
  type        = string
  default     = null
  sensitive   = true
}
