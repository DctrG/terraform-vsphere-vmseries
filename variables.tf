variable "name" {
  description = "Name of the VM-Series virtual machine in vSphere."
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
  description = "Optional vSphere compute cluster name. Used to resolve the cluster root resource pool for vCenter deployments."
  type        = string
  default     = null

  validation {
    condition     = try(length(trimspace(var.cluster_name)) > 0, true)
    error_message = "cluster_name must not be empty when set."
  }
}

variable "host_name" {
  description = "Optional ESXi host name to target for placement. OVA deployment requires host_name or host_system_id."
  type        = string
  default     = null

  validation {
    condition     = try(length(trimspace(var.host_name)) > 0, true)
    error_message = "host_name must not be empty when set."
  }
}

variable "host_system_id" {
  description = "Optional ESXi host managed object ID. Takes precedence over host_name and avoids a host name lookup."
  type        = string
  default     = null

  validation {
    condition     = try(length(trimspace(var.host_system_id)) > 0, true)
    error_message = "host_system_id must not be empty when set."
  }
}

variable "datastore_name" {
  description = "Datastore for the VM configuration and disks."
  type        = string
}

variable "resource_pool_name" {
  description = "Optional resource pool name or inventory path. If null, the cluster root resource pool is used when cluster_name is set."
  type        = string
  default     = null

  validation {
    condition     = try(length(trimspace(var.resource_pool_name)) > 0, true)
    error_message = "resource_pool_name must not be empty when set."
  }
}

variable "resource_pool_id" {
  description = "Optional resource pool managed object ID. Takes precedence over resource_pool_name and cluster_name."
  type        = string
  default     = null

  validation {
    condition     = try(length(trimspace(var.resource_pool_id)) > 0, true)
    error_message = "resource_pool_id must not be empty when set."
  }
}

variable "folder" {
  description = "Optional vSphere VM folder path."
  type        = string
  default     = null
}

variable "ova" {
  description = <<-EOT
    VM-Series image source and deployment options. Set exactly one of local_path, remote_url, source_image_name, or source_image_uuid.
    Use local_path or remote_url to import an OVF/OVA. Use source_image_name or source_image_uuid to clone an already-imported
    vSphere golden image VM/template and avoid uploading/importing the OVA again.
  EOT

  type = object({
    local_path                              = optional(string)
    remote_url                              = optional(string)
    source_image_name                       = optional(string)
    source_image_uuid                       = optional(string)
    source_image_folder                     = optional(string)
    source_image_linked_clone               = optional(bool, false)
    source_image_clone_timeout              = optional(number)
    source_image_scsi_controller_scan_count = optional(number, 1)
    source_image_nvme_controller_scan_count = optional(number, 1)
    allow_unverified_ssl_cert               = optional(bool, false)
    deployment_option                       = optional(string)
    ip_protocol                             = optional(string, "IPV4")
    ip_allocation_policy                    = optional(string, "STATIC_MANUAL")
    enable_hidden_properties                = optional(bool, false)
  })

  validation {
    condition = length([
      for source in [
        try(var.ova.local_path, null),
        try(var.ova.remote_url, null),
        try(var.ova.source_image_name, null),
        try(var.ova.source_image_uuid, null)
      ] : source
      if source != null
    ]) == 1
    error_message = "Set exactly one of ova.local_path, ova.remote_url, ova.source_image_name, or ova.source_image_uuid."
  }

  validation {
    condition = alltrue([
      for source in [
        try(var.ova.local_path, null),
        try(var.ova.remote_url, null),
        try(var.ova.source_image_name, null),
        try(var.ova.source_image_uuid, null),
        try(var.ova.source_image_folder, null)
      ] : source == null ? true : length(trimspace(source)) > 0
    ])
    error_message = "OVA source path, URL, source image name, source image UUID, and source image folder values must be non-empty when set."
  }

  validation {
    condition     = try(var.ova.source_image_clone_timeout, null) == null ? true : var.ova.source_image_clone_timeout > 0
    error_message = "ova.source_image_clone_timeout must be greater than 0 when set."
  }

  validation {
    condition = (
      try(var.ova.source_image_scsi_controller_scan_count, 1) >= 1 &&
      try(var.ova.source_image_nvme_controller_scan_count, 1) >= 1
    )
    error_message = "source image controller scan counts must be greater than or equal to 1."
  }
}

variable "network_interfaces" {
  description = <<-EOT
    Ordered VM-Series interface mappings to vSphere port groups.

    ovf_label is the OVF network name used during import. Set exactly one of network_name or network_id for each adapter.
    Some VM-Series OVAs expose one shared label such as "VM Network" for every adapter. In that case, repeat ovf_label
    and set ovf_mapping to the adapter name from the OVF, such as "Ethernet 1", "Ethernet 2", and "Ethernet 3".
  EOT

  type = list(object({
    ovf_label    = string
    network_name = optional(string)
    network_id   = optional(string)
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
      length(trimspace(nic.adapter_type)) > 0 &&
      (nic.network_name == null ? true : length(trimspace(nic.network_name)) > 0) &&
      (nic.network_id == null ? true : length(trimspace(nic.network_id)) > 0) &&
      (nic.ovf_mapping == null ? true : length(trimspace(nic.ovf_mapping)) > 0)
    ])
    error_message = "network_interfaces entries must include non-empty ovf_label and adapter_type values; network_name, network_id, and ovf_mapping must be non-empty when set."
  }

  validation {
    condition = alltrue([
      for nic in var.network_interfaces :
      (nic.network_name == null) != (nic.network_id == null)
    ])
    error_message = "Each network_interfaces entry must set exactly one of network_name or network_id."
  }

  validation {
    condition = alltrue([
      for nic in var.network_interfaces :
      length([for other in var.network_interfaces : other if other.ovf_label == nic.ovf_label]) == 1 || nic.ovf_mapping != null
    ])
    error_message = "When an ovf_label is used by more than one adapter, every repeated entry must set ovf_mapping."
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

variable "vapp_properties" {
  description = "Additional vApp/OVF property values to set on the VM. Use this for image-specific guestinfo properties not modeled by bootstrap settings."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "custom_attributes" {
  description = "vSphere custom attribute key/value pairs to assign to the VM."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Set of vSphere tag IDs to attach to the VM."
  type        = set(string)
  default     = []
}

variable "storage_policy_id" {
  description = "Optional VM storage policy ID to apply to the VM."
  type        = string
  default     = null
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

variable "wait_for_guest_net_routable" {
  description = "Require guest network routes before considering guest networking ready."
  type        = bool
  default     = true
}

variable "poweron_timeout" {
  description = "Timeout in seconds to wait for the VM to power on."
  type        = number
  default     = 300
}

variable "shutdown_wait_timeout" {
  description = "Timeout in minutes to wait for a graceful guest shutdown before powering off."
  type        = number
  default     = 3
}

variable "force_power_off" {
  description = "Force power off the VM when Terraform needs to destroy or reconfigure it and graceful shutdown is unavailable."
  type        = bool
  default     = true
}

variable "bootstrap" {
  description = <<-EOT
    Optional VM-Series bootstrap generation and attachment settings.

    Modes:
    - enabled=false: no bootstrap settings are applied.
    - enabled=true, create_iso=true: module renders init-cfg.txt, optionally authcodes/bootstrap.xml, builds an ISO locally, uploads it with vsphere_file, and attaches it.
    - enabled=true, create_iso=false, local_iso_path set: module uploads the supplied local ISO and attaches it.
    - enabled=true, create_iso=false, local_iso_path null: module assumes datastore_path already exists and attaches it.
    - enabled=true, vapp_properties_enabled=true: module also renders native VM-Series guestinfo.pa_vm.* vApp properties for OVF images that support them.

    The default datastore_path is <name>-bootstrap.iso at the datastore root. If you set a nested datastore_path,
    pre-create the datastore folders or set create_datastore_directories=true only when those folders do not already exist.
  EOT

  type = object({
    enabled                      = optional(bool, false)
    create_iso                   = optional(bool, true)
    attach_iso                   = optional(bool, true)
    create_datastore_directories = optional(bool, false)
    vapp_properties_enabled      = optional(bool, false)
    work_dir                     = optional(string)
    local_iso_path               = optional(string)
    datastore_name               = optional(string)
    datastore_path               = optional(string)
    management_type              = optional(string, "static")
    ip_address                   = optional(string)
    default_gateway              = optional(string)
    netmask                      = optional(string)
    ipv6_address                 = optional(string)
    ipv6_default_gateway         = optional(string)
    hostname                     = optional(string)
    panorama_server              = optional(string)
    panorama_server_2            = optional(string)
    template_stack               = optional(string)
    device_group                 = optional(string)
    dns_primary                  = optional(string)
    dns_secondary                = optional(string)
    op_command_modes             = optional(string)
    op_cmd_dpdk_pkt_io           = optional(string)
    plugin_op_commands           = optional(string)
    dhcp_send_hostname           = optional(string)
    dhcp_send_client_id          = optional(string)
    dhcp_accept_server_hostname  = optional(string)
    dhcp_accept_server_domain    = optional(string)
    registration_pin_id          = optional(string)
    additional_parameters        = optional(map(string), {})
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

variable "bootstrap_vapp_options" {
  description = "Optional value for the native guestinfo.pa_vm.options vApp property when bootstrap.vapp_properties_enabled is true."
  type        = string
  default     = null
  sensitive   = true
}

variable "bootstrap_vm_auth_key" {
  description = "Optional Panorama VM auth key rendered as vm-auth-key for Panorama registration in the bootstrap ISO and native vApp properties when enabled."
  type        = string
  default     = null
  sensitive   = true
}

variable "bootstrap_auth_key" {
  description = "Optional plugin bootstrap value rendered as auth-key in /config/init-cfg.txt when ISO bootstrap is enabled. This is not a replacement for bootstrap_vm_auth_key."
  type        = string
  default     = null
  sensitive   = true
}

variable "bootstrap_registration_pin_value" {
  description = "Optional VM-Series auto-registration PIN value to include in the bootstrap ISO and native vApp properties when enabled."
  type        = string
  default     = null
  sensitive   = true
}

variable "bootstrap_license_authcodes" {
  description = "Optional VM-Series auth codes. With ISO bootstrap, this is rendered to /license/authcodes. With vApp bootstrap, it is rendered to guestinfo.pa_vm.authcodes."
  type        = string
  default     = null
  sensitive   = true
}

variable "bootstrap_files" {
  description = <<-EOT
    Additional files to include in the generated bootstrap ISO, keyed by path relative to the bootstrap root.
    Paths must be under config/, license/, content/, software/, or plugins/. For each file, set exactly one of
    content, content_base64, or source.
  EOT

  type = map(object({
    content         = optional(string)
    content_base64  = optional(string)
    source          = optional(string)
    file_permission = optional(string, "0600")
  }))

  default   = {}
  sensitive = true

  validation {
    condition = alltrue([
      for path in keys(nonsensitive(var.bootstrap_files)) :
      can(regex("^(config|license|content|software|plugins)/.+[^/]$", path)) &&
      !can(regex("(^|/)\\.\\.?(/|$)", path))
    ])
    error_message = "bootstrap_files keys must be relative file paths under config/, license/, content/, software/, or plugins/ and must not contain . or .. path segments."
  }

  validation {
    condition = alltrue([
      for file in values(var.bootstrap_files) :
      length([
        for value in [file.content, file.content_base64, file.source] : value
        if value != null
      ]) == 1
    ])
    error_message = "Each bootstrap_files entry must set exactly one of content, content_base64, or source."
  }

  validation {
    condition = alltrue([
      for file in values(var.bootstrap_files) :
      file.file_permission == null ? true : can(regex("^[0-7]{3,4}$", file.file_permission))
    ])
    error_message = "bootstrap_files.file_permission values must use 3 or 4 digit octal notation, such as 600 or 0600."
  }
}

variable "bootstrap_xml" {
  description = "Optional full bootstrap.xml configuration content. Most Panorama-managed deployments should leave this null."
  type        = string
  default     = null
  sensitive   = true
}
