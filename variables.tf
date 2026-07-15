variable "name" {
  description = "Name of the VM-Series virtual machine in vSphere."
  type        = string

  validation {
    condition = (
      length(trimspace(var.name)) > 0 &&
      !can(regex("[/\\r\\n]", var.name))
    )
    error_message = "name must not be empty or contain /, carriage returns, or newlines."
  }
}

variable "datacenter" {
  description = "vSphere datacenter name."
  type        = string

  validation {
    condition     = length(trimspace(var.datacenter)) > 0 && !can(regex("[\\r\\n]", var.datacenter))
    error_message = "datacenter must not be empty or contain line breaks."
  }
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

  validation {
    condition = (
      length(trimspace(var.datastore_name)) > 0 &&
      !can(regex("[/\\r\\n]", var.datastore_name))
    )
    error_message = "datastore_name must not be empty or contain / or line breaks."
  }
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

  validation {
    condition     = var.folder == null ? true : length(trimspace(var.folder)) > 0 && !can(regex("[\\r\\n]", var.folder))
    error_message = "folder must not be empty or contain line breaks when set."
  }
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
    source_image_clone_type                 = optional(string, "vcenter")
    source_image_linked_clone               = optional(bool, false)
    source_image_clone_timeout              = optional(number)
    source_image_scsi_controller_scan_count = optional(number, 1)
    source_image_nvme_controller_scan_count = optional(number, 1)
    source_image_vmdk_path                  = optional(string)
    source_image_disk_datastore_path        = optional(string)
    source_image_disk_clone_type            = optional(string, "thin")
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
    condition = try(var.ova.source_image_clone_timeout, null) == null ? true : (
      var.ova.source_image_clone_timeout > 0 &&
      floor(var.ova.source_image_clone_timeout) == var.ova.source_image_clone_timeout
    )
    error_message = "ova.source_image_clone_timeout must be a positive whole number of minutes when set."
  }

  validation {
    condition     = contains(["vcenter", "esxi"], try(var.ova.source_image_clone_type, "vcenter"))
    error_message = "ova.source_image_clone_type must be either vcenter or esxi."
  }

  validation {
    condition     = try(var.ova.source_image_clone_type, "vcenter") != "esxi" || try(var.ova.source_image_vmdk_path, null) != null
    error_message = "ova.source_image_vmdk_path is required when ova.source_image_clone_type is esxi."
  }

  validation {
    condition = (
      try(var.ova.source_image_clone_type, "vcenter") != "esxi" ||
      try(var.ova.source_image_name, null) != null ||
      try(var.ova.source_image_uuid, null) != null
    )
    error_message = "ova.source_image_clone_type can be esxi only when source_image_name or source_image_uuid selects a golden image."
  }

  validation {
    condition     = try(var.ova.source_image_clone_type, "vcenter") != "esxi" || !try(var.ova.source_image_linked_clone, false)
    error_message = "ova.source_image_linked_clone is only supported with ova.source_image_clone_type set to vcenter."
  }

  validation {
    condition = try(var.ova.source_image_vmdk_path, null) == null ? true : (
      startswith(var.ova.source_image_vmdk_path, "/vmfs/volumes/") &&
      endswith(lower(var.ova.source_image_vmdk_path), ".vmdk") &&
      !can(regex("[\\r\\n]", var.ova.source_image_vmdk_path)) &&
      !can(regex("(^|/)\\.\\.?(/|$)", var.ova.source_image_vmdk_path))
    )
    error_message = "ova.source_image_vmdk_path must be an absolute .vmdk descriptor path under /vmfs/volumes without line breaks or dot path segments."
  }

  validation {
    condition = try(var.ova.source_image_disk_datastore_path, null) == null ? true : (
      !startswith(var.ova.source_image_disk_datastore_path, "/") &&
      endswith(lower(var.ova.source_image_disk_datastore_path), ".vmdk") &&
      !can(regex("[\\r\\n]", var.ova.source_image_disk_datastore_path)) &&
      !can(regex("(^|/)\\.\\.?(/|$)", var.ova.source_image_disk_datastore_path))
    )
    error_message = "ova.source_image_disk_datastore_path must be a relative .vmdk path without line breaks or dot path segments."
  }

  validation {
    condition     = contains(["thin", "zeroedthick", "eagerzeroedthick"], try(var.ova.source_image_disk_clone_type, "thin"))
    error_message = "ova.source_image_disk_clone_type must be one of: thin, zeroedthick, eagerzeroedthick."
  }

  validation {
    condition = (
      try(var.ova.source_image_scsi_controller_scan_count, 1) >= 1 &&
      floor(try(var.ova.source_image_scsi_controller_scan_count, 1)) == try(var.ova.source_image_scsi_controller_scan_count, 1) &&
      try(var.ova.source_image_nvme_controller_scan_count, 1) >= 1 &&
      floor(try(var.ova.source_image_nvme_controller_scan_count, 1)) == try(var.ova.source_image_nvme_controller_scan_count, 1)
    )
    error_message = "source image controller scan counts must be positive whole numbers."
  }
}

variable "esxi_ssh_host" {
  description = "Optional ESXi SSH host used only when ova.source_image_clone_type is esxi."
  type        = string
  default     = null

  validation {
    condition     = try(length(trimspace(var.esxi_ssh_host)) > 0, true)
    error_message = "esxi_ssh_host must not be empty when set."
  }
}

variable "esxi_ssh_user" {
  description = "ESXi SSH user used only when ova.source_image_clone_type is esxi."
  type        = string
  default     = "root"

  validation {
    condition     = length(trimspace(var.esxi_ssh_user)) > 0
    error_message = "esxi_ssh_user must not be empty."
  }
}

variable "esxi_ssh_password" {
  description = "Optional ESXi SSH password used only when ova.source_image_clone_type is esxi."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = nonsensitive(var.esxi_ssh_password == null ? true : length(var.esxi_ssh_password) > 0 && !can(regex("[\\r\\n]", var.esxi_ssh_password)))
    error_message = "esxi_ssh_password must not be empty or contain line breaks when set."
  }
}

variable "esxi_ssh_private_key" {
  description = "Optional ESXi SSH private key contents used only when ova.source_image_clone_type is esxi."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = nonsensitive(var.esxi_ssh_private_key == null ? true : length(trimspace(var.esxi_ssh_private_key)) > 0)
    error_message = "esxi_ssh_private_key must not be empty when set."
  }
}

variable "esxi_ssh_port" {
  description = "ESXi SSH port used only when ova.source_image_clone_type is esxi."
  type        = number
  default     = 22

  validation {
    condition     = var.esxi_ssh_port > 0 && var.esxi_ssh_port <= 65535
    error_message = "esxi_ssh_port must be between 1 and 65535."
  }
}

variable "esxi_ssh_timeout" {
  description = "ESXi SSH connection timeout used only when ova.source_image_clone_type is esxi."
  type        = string
  default     = "10m"

  validation {
    condition = (
      can(regex("^([0-9]+(ms|s|m|h))+$", trimspace(var.esxi_ssh_timeout))) &&
      can(regex("[1-9]", trimspace(var.esxi_ssh_timeout)))
    )
    error_message = "esxi_ssh_timeout must be a positive duration such as 30s, 10m, or 1h30m."
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

  validation {
    condition     = var.num_cpus == null ? true : var.num_cpus > 0 && floor(var.num_cpus) == var.num_cpus
    error_message = "num_cpus must be a positive whole number when set."
  }
}

variable "num_cores_per_socket" {
  description = "Optional cores-per-socket override."
  type        = number
  default     = null

  validation {
    condition     = var.num_cores_per_socket == null ? true : var.num_cores_per_socket > 0 && floor(var.num_cores_per_socket) == var.num_cores_per_socket
    error_message = "num_cores_per_socket must be a positive whole number when set."
  }
}

variable "memory_mb" {
  description = "Optional memory override in MB. If null, the OVA default is used."
  type        = number
  default     = null

  validation {
    condition     = var.memory_mb == null ? true : var.memory_mb > 0 && floor(var.memory_mb) == var.memory_mb
    error_message = "memory_mb must be a positive whole number when set."
  }
}

variable "hardware_version" {
  description = "Optional VM virtual hardware version override. If null, standalone ESXi source-image deployments inherit the source image hardware version when available."
  type        = number
  default     = null

  validation {
    condition     = var.hardware_version == null ? true : var.hardware_version > 0 && floor(var.hardware_version) == var.hardware_version
    error_message = "hardware_version must be a positive whole number when set."
  }
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

  validation {
    condition     = var.storage_policy_id == null ? true : length(trimspace(var.storage_policy_id)) > 0 && !can(regex("[\\r\\n]", var.storage_policy_id))
    error_message = "storage_policy_id must not be empty or contain line breaks when set."
  }
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

  validation {
    condition     = var.wait_for_guest_ip_timeout >= 0 && floor(var.wait_for_guest_ip_timeout) == var.wait_for_guest_ip_timeout
    error_message = "wait_for_guest_ip_timeout must be a non-negative whole number of minutes."
  }
}

variable "wait_for_guest_net_timeout" {
  description = "Timeout in minutes to wait for guest networking. VM-Series does not normally report this reliably before bootstrap, so the default is 0."
  type        = number
  default     = 0

  validation {
    condition     = var.wait_for_guest_net_timeout >= 0 && floor(var.wait_for_guest_net_timeout) == var.wait_for_guest_net_timeout
    error_message = "wait_for_guest_net_timeout must be a non-negative whole number of minutes."
  }
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

  validation {
    condition     = var.poweron_timeout > 0 && floor(var.poweron_timeout) == var.poweron_timeout
    error_message = "poweron_timeout must be a positive whole number of seconds."
  }
}

variable "shutdown_wait_timeout" {
  description = "Timeout in minutes to wait for a graceful guest shutdown before powering off."
  type        = number
  default     = 3

  validation {
    condition     = var.shutdown_wait_timeout >= 0 && floor(var.shutdown_wait_timeout) == var.shutdown_wait_timeout
    error_message = "shutdown_wait_timeout must be a non-negative whole number of minutes."
  }
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

  validation {
    condition = alltrue([
      for value in [
        var.bootstrap.work_dir,
        var.bootstrap.local_iso_path,
        var.bootstrap.datastore_name,
        var.bootstrap.ip_address,
        var.bootstrap.default_gateway,
        var.bootstrap.netmask,
        var.bootstrap.ipv6_address,
        var.bootstrap.ipv6_default_gateway,
        var.bootstrap.hostname,
        var.bootstrap.panorama_server,
        var.bootstrap.panorama_server_2,
        var.bootstrap.template_stack,
        var.bootstrap.device_group,
        var.bootstrap.dns_primary,
        var.bootstrap.dns_secondary,
        var.bootstrap.op_command_modes,
        var.bootstrap.op_cmd_dpdk_pkt_io,
        var.bootstrap.plugin_op_commands,
        var.bootstrap.dhcp_send_hostname,
        var.bootstrap.dhcp_send_client_id,
        var.bootstrap.dhcp_accept_server_hostname,
        var.bootstrap.dhcp_accept_server_domain,
        var.bootstrap.registration_pin_id
      ] : value == null ? true : length(trimspace(value)) > 0 && !can(regex("[\\r\\n]", value))
    ])
    error_message = "Bootstrap string values must not be empty or contain line breaks when set."
  }

  validation {
    condition = var.bootstrap.datastore_path == null ? true : (
      length(trimspace(var.bootstrap.datastore_path)) > 0 &&
      !startswith(var.bootstrap.datastore_path, "/") &&
      !can(regex("[\\r\\n]", var.bootstrap.datastore_path)) &&
      !can(regex("(^|/)\\.\\.?(/|$)", var.bootstrap.datastore_path))
    )
    error_message = "bootstrap.datastore_path must be a non-empty datastore-relative path without line breaks or dot path segments."
  }

  validation {
    condition = alltrue([
      for key, value in var.bootstrap.additional_parameters :
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", key)) &&
      (value == null ? true : !can(regex("[\\r\\n]", value)))
    ])
    error_message = "bootstrap.additional_parameters keys must contain only letters, numbers, dots, underscores, or hyphens, and values must be single-line strings."
  }

  validation {
    condition = alltrue([
      for key in keys(var.bootstrap.additional_parameters) : !contains([
        "type",
        "ip-address",
        "default-gateway",
        "netmask",
        "ipv6-address",
        "ipv6-default-gateway",
        "hostname",
        "panorama-server",
        "panorama-server-2",
        "tplname",
        "dgname",
        "dns-primary",
        "dns-secondary",
        "auth-key",
        "vm-auth-key",
        "op-command-modes",
        "op-cmd-dpdk-pkt-io",
        "plugin-op-commands",
        "dhcp-send-hostname",
        "dhcp-send-client-id",
        "dhcp-accept-server-hostname",
        "dhcp-accept-server-domain",
        "vm-series-auto-registration-pin-id",
        "vm-series-auto-registration-pin-value"
      ], lower(key))
    ])
    error_message = "bootstrap.additional_parameters must not redefine a bootstrap key modeled by this module."
  }

  validation {
    condition = alltrue([
      for value in [
        var.bootstrap.dhcp_send_hostname,
        var.bootstrap.dhcp_send_client_id,
        var.bootstrap.dhcp_accept_server_hostname,
        var.bootstrap.dhcp_accept_server_domain
      ] : value == null ? true : contains(["yes", "no"], value)
    ])
    error_message = "Bootstrap DHCP boolean settings must be yes or no when set."
  }

  validation {
    condition     = var.bootstrap.op_cmd_dpdk_pkt_io == null ? true : contains(["on", "off"], var.bootstrap.op_cmd_dpdk_pkt_io)
    error_message = "bootstrap.op_cmd_dpdk_pkt_io must be on or off when set."
  }
}

variable "bootstrap_vapp_options" {
  description = "Optional value for the native guestinfo.pa_vm.options vApp property when bootstrap.vapp_properties_enabled is true."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = nonsensitive(var.bootstrap_vapp_options == null ? true : length(trimspace(var.bootstrap_vapp_options)) > 0 && !can(regex("[\\r\\n]", var.bootstrap_vapp_options)))
    error_message = "bootstrap_vapp_options must not be empty or contain line breaks when set."
  }
}

variable "bootstrap_vm_auth_key" {
  description = "Optional Panorama VM auth key rendered as vm-auth-key for workflows that explicitly require that key."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = nonsensitive(var.bootstrap_vm_auth_key == null ? true : length(trimspace(var.bootstrap_vm_auth_key)) > 0 && !can(regex("[\\r\\n]", var.bootstrap_vm_auth_key)))
    error_message = "bootstrap_vm_auth_key must not be empty or contain line breaks when set."
  }
}

variable "bootstrap_auth_key" {
  description = "Optional Panorama/plugin bootstrap value rendered as auth-key in /config/init-cfg.txt and native vApp properties when enabled. Use this for Software Firewall License plugin onboarding when Panorama returns an auth-key."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = nonsensitive(var.bootstrap_auth_key == null ? true : length(trimspace(var.bootstrap_auth_key)) > 0 && !can(regex("[\\r\\n]", var.bootstrap_auth_key)))
    error_message = "bootstrap_auth_key must not be empty or contain line breaks when set."
  }
}

variable "bootstrap_registration_pin_value" {
  description = "Optional VM-Series auto-registration PIN value to include in the bootstrap ISO and native vApp properties when enabled."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = nonsensitive(var.bootstrap_registration_pin_value == null ? true : length(trimspace(var.bootstrap_registration_pin_value)) > 0 && !can(regex("[\\r\\n]", var.bootstrap_registration_pin_value)))
    error_message = "bootstrap_registration_pin_value must not be empty or contain line breaks when set."
  }
}

variable "bootstrap_license_authcodes" {
  description = "Optional VM-Series auth codes. With ISO bootstrap, this is rendered to /license/authcodes. With vApp bootstrap, it is rendered to guestinfo.pa_vm.authcodes."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = nonsensitive(var.bootstrap_license_authcodes == null ? true : length(trimspace(var.bootstrap_license_authcodes)) > 0)
    error_message = "bootstrap_license_authcodes must not be empty when set."
  }
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

  validation {
    condition     = nonsensitive(var.bootstrap_xml == null ? true : length(trimspace(var.bootstrap_xml)) > 0)
    error_message = "bootstrap_xml must not be empty when set."
  }
}
