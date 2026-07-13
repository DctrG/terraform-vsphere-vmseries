# terraform-vsphere-vmseries

Terraform module for deploying a Palo Alto Networks VM-Series firewall OVA into VMware vSphere / VMware private cloud.

This module is intentionally focused on the infrastructure side of a private-cloud VM-Series deployment:

- Deploy a VM-Series OVA with the VMware vSphere Terraform provider.
- Map OVF network labels to vSphere port groups.
- Optionally generate a PAN-OS bootstrap package.
- Optionally build and upload a bootstrap ISO to a datastore.
- Optionally attach the bootstrap ISO as a vSphere CD-ROM.
- Optionally set native VM-Series `guestinfo.pa_vm.*` OVF/vApp bootstrap properties.

Panorama / PAN-OS policy, templates, device groups, CSP licensing inventory, and commit operations should be handled separately with Panorama, the PAN-OS API, Ansible, CI/CD, or the Palo Alto Networks PAN-OS Terraform provider. This module can pass bootstrap licensing and Panorama registration values to the VM-Series appliance, but it does not manage Panorama or CSP state.

## Supported Patterns

- Import a VM-Series OVA from a local file path or HTTPS URL.
- Clone from an already-imported VM-Series golden image VM/template.
- Deploy through vCenter clusters or standalone ESXi inventory.
- Resolve placement by cluster, resource pool name, resource pool ID, host name, or host managed object ID.
- Bootstrap with an ISO, native `guestinfo.pa_vm.*` vApp properties, or both.
- Include additional bootstrap files for content, software, plugin, license, or config artifacts.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| vmware/vsphere | >= 2.14, < 3.0 |
| hashicorp/local | >= 2.4, < 3.0 |

For bootstrap ISO creation, the Terraform runner must have one of these installed:

- `genisoimage`
- `mkisofs`
- `xorrisofs`
- macOS `hdiutil`

If you do not want Terraform to build the ISO, set `bootstrap.create_iso = false` and either pass `bootstrap.local_iso_path` for upload or pass only `bootstrap.datastore_path` to attach a pre-existing datastore ISO.

By default, generated bootstrap ISOs are uploaded to the datastore root as `<name>-bootstrap.iso`. If you set `bootstrap.datastore_path` to a nested path, pre-create the datastore folders or set `bootstrap.create_datastore_directories = true` for first-time folder creation.

## vSphere Prerequisites

Ensure these vSphere objects are available to the Terraform user:

- A datacenter, datastore, and either a compute cluster, resource pool name, or resource pool ID visible to the Terraform user.
- For OVA imports, a target ESXi host supplied by `host_name` or `host_system_id`.
- One VM folder if you set `folder`; the module does not create folders.
- Port groups or NSX segments for management and dataplane adapters.
- A local OVA path visible to the Terraform runner, an HTTPS URL in `ova.remote_url`, or an already-imported golden image VM/template to clone with `ova.source_image_name` or `ova.source_image_uuid`.
- For bootstrap ISO generation, one supported ISO builder on the Terraform runner.

For standalone ESXi deployments, use the host's local inventory values, such as `datacenter = "ha-datacenter"` and `resource_pool_name = "Resources"`, or pass a discovered `resource_pool_id`.

The OVA virtual hardware family must be supported by the target ESXi/vCenter version. The module does not down-convert OVF descriptors; if vSphere reports an error such as `Unsupported hardware family 'vmx-19'`, use a compatible VM-Series image, import a compatible golden image and clone it with `ova.source_image_name` or `ova.source_image_uuid`, or upgrade the vSphere environment.

## OVA Network Mapping

Inspect the OVA descriptor before setting `network_interfaces`:

```bash
scripts/inspect-ova-networks.sh /path/to/PA-VM-ESX.ova
```

Many VM-Series ESXi OVAs expose one OVF network label, such as `VM Network`, and adapters named `Ethernet 1`, `Ethernet 2`, and `Ethernet 3`. Map those adapters in order: management, untrust, then trust, unless your design uses a different interface order.

Use `network_name` for normal port group lookups. If names are ambiguous in vCenter, pass `network_id` instead:

```hcl
network_interfaces = [
  { ovf_label = "VM Network", ovf_mapping = "Ethernet 1", network_id = "network-123" },
  { ovf_label = "VM Network", ovf_mapping = "Ethernet 2", network_id = "dvportgroup-456" },
  { ovf_label = "VM Network", ovf_mapping = "Ethernet 3", network_id = "dvportgroup-789" }
]
```

## Basic OVA Deployment

```hcl
provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

module "vmseries" {
  source  = "DctrG/vmseries/vsphere"
  version = "~> 0.1"

  name           = "pa-vmseries-01"
  datacenter     = "DC1"
  cluster_name   = "Cluster01"
  host_name      = "esxi-01.example.local"
  datastore_name = "vsanDatastore"

  ova = {
    source_image_name = "templates/PA-VM-Series-Golden"
  }

  network_interfaces = [
    {
      ovf_label    = "VM Network"
      ovf_mapping  = "Ethernet 1"
      network_name = "PG-MGMT"
    },
    {
      ovf_label    = "VM Network"
      ovf_mapping  = "Ethernet 2"
      network_name = "PG-UNTRUST"
    },
    {
      ovf_label    = "VM Network"
      ovf_mapping  = "Ethernet 3"
      network_name = "PG-TRUST"
    }
  ]
}
```

For a standalone ESXi host, omit `cluster_name` and set `resource_pool_name` or `resource_pool_id`:

```hcl
datacenter         = "ha-datacenter"
cluster_name       = null
host_name          = "localhost.localdomain"
resource_pool_name = "Resources"
```

> VM-Series OVA labels can vary by PAN-OS image and build. Inspect the OVA/OVF descriptor if deployment fails with a network mapping error.

## Reusing a Golden Image

For repeated deployments, create a vSphere golden image once by importing the VM-Series OVA and converting the result into the VM or template your team wants to clone. Then point this module at that golden image instead of supplying `ova.local_path` or `ova.remote_url`. Terraform will clone the golden image and skip the OVF/OVA import.

```hcl
module "vmseries" {
  source  = "DctrG/vmseries/vsphere"
  version = "~> 0.1"

  name           = "pa-vmseries-02"
  datacenter     = "DC1"
  cluster_name   = "Cluster01"
  host_name      = "esxi-01.example.local"
  datastore_name = "vsanDatastore"

  ova = {
    source_image_name = "templates/PA-VM-Series-Golden"
  }

  network_interfaces = [
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 1", network_name = "PG-MGMT" },
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 2", network_name = "PG-UNTRUST" },
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 3", network_name = "PG-TRUST" }
  ]
}
```

The golden image must be an existing vSphere VM/template, not only a raw `.ova` file uploaded to a datastore. Use `source_image_name` or `source_image_uuid` for later VMs after the golden image exists.

## Panorama Bootstrap

```hcl
module "vmseries" {
  source  = "DctrG/vmseries/vsphere"
  version = "~> 0.1"

  name           = "pa-vmseries-01"
  datacenter     = "DC1"
  cluster_name   = "Cluster01"
  host_name      = "esxi-01.example.local"
  datastore_name = "vsanDatastore"

  ova = {
    source_image_name = "templates/PA-VM-Series-Golden"
  }

  network_interfaces = [
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 1", network_name = "PG-MGMT" },
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 2", network_name = "PG-UNTRUST" },
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 3", network_name = "PG-TRUST" }
  ]

  bootstrap = {
    enabled        = true
    create_iso     = true
    attach_iso     = true
    datastore_path = "pa-vmseries-01-bootstrap.iso"

    management_type = "static"
    ip_address      = "10.10.10.51"
    default_gateway = "10.10.10.1"
    netmask         = "255.255.255.0"
    hostname        = "pa-vmseries-01"

    panorama_server = "10.10.20.10"
    template_stack  = "TS-VMWARE"
    device_group    = "DG-VMWARE"
    dns_primary     = "10.10.10.10"
    dns_secondary   = "10.10.10.11"

    op_cmd_dpdk_pkt_io = "on"
    plugin_op_commands = "panorama-licensing-mode-on"
  }

  bootstrap_auth_key          = var.bootstrap_auth_key
  bootstrap_license_authcodes = var.bootstrap_license_authcodes
}
```

For Software Firewall License plugin workflows, use the Panorama-generated bootstrap `auth-key` for `bootstrap_auth_key`. The module renders it as `auth-key` in `/config/init-cfg.txt`; with `plugin-op-commands=panorama-licensing-mode-on`, this is the path tested for automated licensing and Panorama onboarding.

`bootstrap_vm_auth_key` is still available for workflows that explicitly require `vm-auth-key`. Do not mix `auth-key`, `vm-auth-key`, registration PIN values, or license auth codes unless the Panorama/plugin bootstrap output for your workflow includes those fields; they render to different keys and trigger different bootstrap paths.

Software Firewall License plugin onboarding may take a few minutes after the VM first becomes reachable. The firewall can briefly show `serial: unknown` and `Connected: no` before the license is installed, the management plane restarts, and Panorama accepts the connection. After the firewall auto-registers, Panorama may place the serial number into candidate configuration for the requested device group and template stack. Commit Panorama so the new serial is present in running configuration, then push policy/templates with the workflow your environment uses.

## Inputs

Key inputs are below. See `variables.tf` for the full contract.

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name` | VM name in vSphere | `string` | required |
| `datacenter` | vSphere datacenter | `string` | required |
| `cluster_name` | Optional compute cluster used to resolve the root resource pool | `string` | `null` |
| `host_name` | Optional ESXi host name for placement; OVA imports require `host_name` or `host_system_id` | `string` | `null` |
| `host_system_id` | Optional ESXi host managed object ID; takes precedence over `host_name` | `string` | `null` |
| `datastore_name` | VM datastore | `string` | required |
| `resource_pool_name` | Optional resource pool name or inventory path | `string` | `null` |
| `resource_pool_id` | Optional resource pool managed object ID | `string` | `null` |
| `ova` | OVA import or existing golden image clone options | `object` | required |
| `network_interfaces` | Ordered VM-Series adapter mappings to vSphere port groups | `list(object)` | required |
| `custom_attributes` | vSphere custom attribute key/value pairs | `map(string)` | `{}` |
| `tags` | vSphere tag IDs to attach to the VM | `set(string)` | `[]` |
| `storage_policy_id` | Optional VM storage policy ID | `string` | `null` |
| `vapp_properties` | Additional vApp/OVF property values to set on the VM | `map(string)` | `{}` |
| `bootstrap` | Bootstrap ISO and native vApp property settings | `object` | disabled |
| `bootstrap_auth_key` | Panorama/plugin bootstrap value rendered as `auth-key`; use for Software Firewall License plugin onboarding when Panorama returns an `auth-key` | `string` | `null` |
| `bootstrap_vapp_options` | Optional value for native `guestinfo.pa_vm.options` when vApp bootstrap is enabled | `string` | `null` |
| `bootstrap_vm_auth_key` | Panorama VM auth key rendered as `vm-auth-key` for workflows that explicitly require that key | `string` | `null` |
| `bootstrap_registration_pin_value` | VM-Series auto-registration PIN value rendered as `vm-series-auto-registration-pin-value` | `string` | `null` |
| `bootstrap_license_authcodes` | `/license/authcodes` content | `string` | `null` |
| `bootstrap_files` | Additional generated bootstrap ISO files under `config/`, `license/`, `content/`, `software/`, or `plugins/` | `map(object)` | `{}` |
| `bootstrap_xml` | Optional `/config/bootstrap.xml` content | `string` | `null` |

## Outputs

| Name | Description |
|------|-------------|
| `id` | Terraform resource ID |
| `uuid` | VM BIOS UUID |
| `moid` | vSphere managed object ID |
| `management_ip_address` | Static management IP supplied via bootstrap |
| `bootstrap_iso_datastore_path` | Datastore path for attached bootstrap ISO |
| `ovf_network_map` | Resolved OVF label to network ID map |
| `network_interface_ids` | Ordered map of adapter index to resolved network ID |

## Bootstrap behavior

When `bootstrap.enabled = true` and `bootstrap.create_iso = true`, the module creates this package structure locally:

```text
/config/init-cfg.txt
/config/bootstrap.xml        # optional
/license/authcodes          # optional
/software/
/content/
/plugins/
```

It then builds an ISO, uploads it to the target datastore with `vsphere_file`, and attaches it as a datastore-backed CD-ROM.

The default upload path is `<name>-bootstrap.iso` at the datastore root. This avoids repeated apply failures caused by provider-side directory creation when a datastore folder already exists. If your environment requires nested datastore paths, create those folders outside this module or set `bootstrap.create_datastore_directories = true` only when the folders do not already exist.

Use `bootstrap_files` to add environment-specific bootstrap artifacts without changing the module. Each key is a file path relative to the bootstrap root and must be under `config/`, `license/`, `content/`, `software/`, or `plugins/`. Each entry sets exactly one of `content`, `content_base64`, or `source`:

```hcl
bootstrap_files = {
  "content/README.txt" = {
    content = "Optional content files can be included here.\n"
  }

  "plugins/plugin-package.tgz" = {
    source = "/secure/artifacts/plugin-package.tgz"
  }
}
```

For VM-Series OVAs that expose native OVF properties, set `bootstrap.vapp_properties_enabled = true` to populate supported `guestinfo.pa_vm.*` keys on the VM:

```hcl
bootstrap = {
  enabled                 = true
  create_iso              = false
  attach_iso              = false
  vapp_properties_enabled = true
  management_type         = "dhcp-client"
  hostname                = "pa-vmseries-01"
  panorama_server         = "10.10.20.10"
  template_stack          = "TS-VMWARE"
  device_group            = "DG-VMWARE"
}

bootstrap_auth_key               = var.bootstrap_auth_key
bootstrap_license_authcodes      = var.bootstrap_license_authcodes
bootstrap_vapp_options           = var.bootstrap_vapp_options
```

Use `vapp_properties` for image-specific OVF properties that are not modeled by the bootstrap object. Values supplied in `vapp_properties` override generated keys with the same name.

Sensitive values such as `bootstrap_auth_key`, `bootstrap_vm_auth_key`, `bootstrap_registration_pin_value`, `bootstrap_license_authcodes`, `bootstrap_files`, `bootstrap_vapp_options`, `vapp_properties`, and `bootstrap_xml` are marked sensitive, but they are still written to the local bootstrap work directory, vSphere VM configuration, or Terraform state depending on the selected bootstrap path. Use a secure runner and encrypted remote state.

## Non-goals

This module does not:

- Generate Panorama VM auth keys.
- Create Panorama template stacks or device groups.
- Commit Panorama or PAN-OS configuration, including the Panorama commit usually required after auto-registration adds a new serial to candidate configuration.
- Register licenses through CSP.
- Configure NSX-T service insertion.
- Implement autoscaling.

## Recommended production pattern

For production, prefer a two-stage pipeline:

1. Platform pipeline: deploy the VM-Series appliance with this module.
2. Security pipeline: use Panorama / PAN-OS automation to assign the device to policy, templates, licensing, content updates, and commits.

This keeps vSphere lifecycle and firewall policy lifecycle separated.
