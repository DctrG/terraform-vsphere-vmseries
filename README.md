# Palo Alto Networks VM-Series Module for VMware vSphere

[![Terraform](https://github.com/DctrG/terraform-vsphere-vmseries/actions/workflows/terraform.yml/badge.svg)](https://github.com/DctrG/terraform-vsphere-vmseries/actions/workflows/terraform.yml)

Terraform module for deploying Palo Alto Networks VM-Series firewalls on VMware vSphere or standalone ESXi.

The module owns the VM infrastructure and first-boot transport:

- Import a VM-Series OVA or clone a clean golden image.
- Map OVF adapters to vSphere networks.
- Generate, upload, and attach a PAN-OS bootstrap ISO.
- Optionally set native `guestinfo.pa_vm.*` OVF/vApp properties.
- Add software, content, plugin, license, or configuration files to the bootstrap package.

Panorama configuration, Software Firewall License plugin state, Flex Credits inventory, policy, and commits remain outside this module. Use Panorama, the PAN-OS API, Ansible, or the Palo Alto Networks PAN-OS Terraform provider for those tasks.

## Deployment Modes

| Image path | Use when | Module setting |
|---|---|---|
| OVA import | Creating the first VM or a golden image | `ova.local_path` or `ova.remote_url` |
| vCenter clone | Repeated deployments from an imported VM/template | `ova.source_image_name` or `ova.source_image_uuid` |
| Standalone ESXi clone | Reusing a golden VMDK without vCenter | Source image plus `ova.source_image_clone_type = "esxi"` |

Use a clean golden image that has never been licensed, registered to Panorama, or customized as a specific firewall. A never-booted imported VM/template is the safest source for repeated first-boot testing.

## Prerequisites

The Terraform runner needs `genisoimage`, `mkisofs`, `xorrisofs`, or macOS `hdiutil` when `bootstrap.create_iso = true`.

The target environment must provide:

- A datacenter, datastore, resource pool or cluster, and target port groups.
- An ESXi host for OVA imports, selected by `host_name` or `host_system_id`.
- A pre-existing VM folder when `folder` is set.
- An image source accessible to the Terraform runner or vSphere inventory.
- SSH access to ESXi when using the standalone ESXi golden-image path.

The module does not down-convert OVF hardware versions. Use a VM-Series image compatible with the target ESXi/vCenter release. The vSphere provider is pinned below `2.16` because `2.16.x` fails in the tested standalone ESXi source-image path.

## Usage

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
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 1", network_name = "PG-MGMT" },
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 2", network_name = "PG-UNTRUST" },
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 3", network_name = "PG-TRUST" }
  ]
}
```

Inspect an OVA before assigning `ovf_label` and `ovf_mapping`:

```bash
scripts/inspect-ova-networks.sh /path/to/PA-VM-ESX.ova
```

VM-Series images commonly expose one OVF network label, such as `VM Network`, with adapters named `Ethernet 1`, `Ethernet 2`, and `Ethernet 3`. Map adapters in management, untrust, and trust order unless the design requires a different layout. Use `network_id` instead of `network_name` when inventory names are ambiguous.

For standalone ESXi, omit `cluster_name` and set the local inventory values:

```hcl
datacenter         = "ha-datacenter"
cluster_name       = null
host_name          = "localhost.localdomain"
resource_pool_name = "Resources"
```

See [examples/basic-ova](examples/basic-ova) for an OVA import and [examples/panorama-bootstrap](examples/panorama-bootstrap) for a complete golden-image and bootstrap deployment.

## Golden Images

With vCenter, select an existing VM or template:

```hcl
ova = {
  source_image_name = "templates/PA-VM-Series-Golden"
}
```

With standalone ESXi, the provider cannot use the native `clone` block. The module copies the selected VMDK with `vmkfstools` over SSH, creates the VM, and attaches the per-VM disk:

```hcl
ova = {
  source_image_name       = "PA-VM-Series-Golden"
  source_image_clone_type = "esxi"
  source_image_vmdk_path  = "/vmfs/volumes/datastore1/PA-VM-Series-Golden/PA-VM-Series-Golden.vmdk"
}

esxi_ssh_host        = "192.0.2.10"
esxi_ssh_user        = "root"
esxi_ssh_private_key = var.esxi_ssh_private_key
```

The default destination is `<name>-disk/<name>.vmdk` on `datastore_name`. The module refuses to overwrite an existing destination VMDK. Use a new VM name or `ova.source_image_disk_datastore_path` for replacements, and never point the destination at the golden image disk.

## Bootstrap Transport

Choose one bootstrap transport, or intentionally combine ISO and native vApp properties:

| Mode | Settings | Behavior |
|---|---|---|
| Generated ISO | `enabled = true`, `create_iso = true`, `attach_iso = true` | Render files, build an ISO, upload it, and attach it |
| Supplied local ISO | `enabled = true`, `create_iso = false`, set `local_iso_path` | Upload and attach the supplied ISO |
| Existing datastore ISO | `enabled = true`, `create_iso = false`, set `datastore_path` | Attach the existing datastore ISO |
| Native vApp properties | `enabled = true`, `vapp_properties_enabled = true` | Set supported `guestinfo.pa_vm.*` properties; configure ISO settings separately |

The generated ISO contains:

```text
/config/init-cfg.txt
/config/bootstrap.xml       # optional
/license/authcodes          # optional, direct-license workflows only
/software/
/content/
/plugins/
```

The default datastore destination is `<name>-bootstrap.iso` at the datastore root. For nested paths, pre-create the folders or set `bootstrap.create_datastore_directories = true` only for first-time folder creation.

### Panorama Software Firewall License Plugin

This workflow follows Palo Alto Networks' [Panorama-based Software Firewall License Management](https://docs.paloaltonetworks.com/vm-series/activation-and-onboarding/vm-series-firewall-licensing/use-panorama-based-software-firewall-license-management) process. Use the generated ISO path so PAN-OS receives the plugin command through `/config/init-cfg.txt`.

Palo Alto Networks does not support this plugin workflow for PAYG licenses or VM-Series firewalls deployed for VMware NSX. Confirm the current Panorama, PAN-OS, and plugin compatibility requirements in the linked documentation.

#### 1. Prepare Panorama

1. Install a compatible Software Firewall License plugin on Panorama.
2. Create a **Bootstrap Definition** and put the Flex Credits/CSP license auth code in that Panorama object.
3. Create a **License Manager** that selects the Bootstrap Definition, device group, and template stack.
4. Commit the Panorama configuration.
5. From the License Manager, select **Show Bootstrap Parameters**.

The Flex Credits/CSP auth code stays in Panorama's Bootstrap Definition. Do not pass it to this module as `bootstrap_auth_key` or `bootstrap_license_authcodes` for the plugin workflow.

Panorama always generates these two bootstrap values for the License Manager:

- `auth-key=<Panorama-generated value>`
- `plugin-op-commands=panorama-licensing-mode-on`

The generated `auth-key` replaces a manually generated VM auth key. Do not use both.

#### 2. Pass the generated parameters to the module

```hcl
module "vmseries" {
  source  = "DctrG/vmseries/vsphere"
  version = "~> 0.1"

  # vSphere, image, and network arguments omitted here for focus.

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
    dns_primary     = "10.10.10.10"

    panorama_server    = "panorama.example.com"
    template_stack     = "TS-VMWARE"
    device_group       = "DG-VMWARE"
    plugin_op_commands = "panorama-licensing-mode-on"
  }

  bootstrap_auth_key = var.panorama_license_manager_auth_key
}
```

Use the Panorama address reachable from the firewall management interface. If Panorama is behind NAT, replace a private address shown by **Show Bootstrap Parameters** with the public IP or DNS name that the firewall can reach.

The relevant generated `init-cfg.txt` lines are:

```text
panorama-server=panorama.example.com
tplname=TS-VMWARE
dgname=DG-VMWARE
auth-key=<Panorama-generated value>
plugin-op-commands=panorama-licensing-mode-on
```

The module renders `auth-key` before `plugin-op-commands` and packages the file at `/config/init-cfg.txt`.

#### 3. Complete onboarding

After `terraform apply`, allow the firewall to complete first boot:

1. PAN-OS reads the bootstrap ISO and enters Panorama licensing mode.
2. The management interface connects to the configured Panorama address.
3. Panorama uses the License Manager's Bootstrap Definition to assign capacity and license the firewall.
4. The firewall receives a serial number and can restart its management plane while licensing completes.
5. Panorama associates the firewall with the selected device group and template stack.
6. Commit Panorama if auto-registration added the serial number to candidate configuration, then push policy and templates through the normal security workflow.

Verify the firewall first under **Panorama > SW Firewall License > License Managers > Show Devices**, then under Panorama Managed Devices. The firewall can briefly show `serial: unknown`, `Connected: no`, or `vm-license: none` before licensing and the management-plane restart finish.

If onboarding does not complete, check:

- The VM came from a clean, unlicensed image and consumed the ISO on first boot.
- The firewall can route to and resolve `panorama-server` from its management interface.
- The License Manager was committed and references the intended Bootstrap Definition, device group, and template stack.
- `bootstrap_auth_key` is current and exactly matches **Show Bootstrap Parameters**; generate a fresh value in Panorama when an older key has expired.
- `bootstrap.plugin_op_commands` is exactly `panorama-licensing-mode-on`.
- `bootstrap_vm_auth_key`, `bootstrap_license_authcodes`, and registration PIN values are unset.
- Panorama has available Flex Credits capacity and its plugin API requests succeed (`show plugins sw_fw_license panorama-api-requests`).

If a replacement repeatedly inherits stale licensing identity, deploy it with a fresh vSphere VM name and datastore path. Preserve the intended PAN-OS name with `bootstrap.hostname`, verify the replacement, and only then remove the old VM.

### Credential Paths

These inputs are not interchangeable:

| Workflow | Module input | Rendered value |
|---|---|---|
| Software Firewall License plugin | `bootstrap_auth_key` | `auth-key` in `/config/init-cfg.txt` |
| Regular Panorama bootstrap requiring a VM auth key | `bootstrap_vm_auth_key` | `vm-auth-key` in `/config/init-cfg.txt` |
| Direct firewall licensing | `bootstrap_license_authcodes` | ISO: `/license/authcodes`; vApp: `guestinfo.pa_vm.authcodes` |
| Auto-registration PIN | `bootstrap.registration_pin_id` and `bootstrap_registration_pin_value` | Auto-registration PIN fields |

For the Software Firewall License plugin row, also set `bootstrap.plugin_op_commands = "panorama-licensing-mode-on"`. Leave the other credential inputs unset.

`bootstrap.plugin_op_commands` is written to `init-cfg.txt`; it is not emitted as a native vApp property. Therefore, do not use the module's vApp-only mode for this plugin workflow unless the selected VM-Series image documentation provides an equivalent, explicitly configured `guestinfo.pa_vm.options` value.

### Additional Bootstrap Files

Use `bootstrap_files` for environment-specific artifacts. Paths must be under `config/`, `license/`, `content/`, `software/`, or `plugins/`, and each entry must set exactly one content source:

```hcl
bootstrap_files = {
  "plugins/plugin-package.tgz" = {
    source = "/secure/artifacts/plugin-package.tgz"
  }
}
```

For VM-Series images that support native OVF properties, `bootstrap.vapp_properties_enabled = true` populates the modeled `guestinfo.pa_vm.*` keys. Use `vapp_properties` for image-specific keys; explicit map values override generated keys with the same name.

## Security and Lifecycle

Sensitive variables are marked sensitive, but Terraform still sends or stores them where the selected workflow requires. Values can appear in Terraform state, generated bootstrap files, vSphere VM configuration, or attached media. Use a trusted runner, encrypted remote state, restricted datastore access, and short-lived bootstrap credentials where supported.

This module intentionally does not create Panorama objects, operate the licensing plugin, consume CSP inventory, commit Panorama/PAN-OS configuration, configure NSX-T service insertion, or implement autoscaling.

For production, separate the lifecycle into two pipelines:

1. Platform pipeline: deploy the VM-Series appliance and first-boot transport with this module.
2. Security pipeline: license, register, commit, update content, and push policy through Panorama/PAN-OS automation.

See [SECURITY.md](SECURITY.md) for sensitive-data guidance, [CONTRIBUTING.md](CONTRIBUTING.md) for development checks, and [RELEASING.md](RELEASING.md) for the Registry release process.

## Reference

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.4, < 3.0 |
| <a name="requirement_vsphere"></a> [vsphere](#requirement\_vsphere) | >= 2.14, < 2.16 |

### Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_local"></a> [local](#provider\_local) | >= 2.4, < 3.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_vsphere"></a> [vsphere](#provider\_vsphere) | >= 2.14, < 2.16 |

### Modules

No modules.

### Resources

| Name | Type |
| ---- | ---- |
| [local_sensitive_file.bootstrap_files](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [local_sensitive_file.bootstrap_xml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [local_sensitive_file.init_cfg](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [local_sensitive_file.license_authcodes](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [terraform_data.bootstrap_dirs](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.bootstrap_iso](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.esxi_disk_clone](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [vsphere_file.bootstrap_iso](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/resources/file) | resource |
| [vsphere_virtual_machine.this](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/resources/virtual_machine) | resource |
| [vsphere_compute_cluster.this](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/data-sources/compute_cluster) | data source |
| [vsphere_datacenter.this](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/data-sources/datacenter) | data source |
| [vsphere_datastore.bootstrap](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/data-sources/datastore) | data source |
| [vsphere_datastore.vm](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/data-sources/datastore) | data source |
| [vsphere_host.this](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/data-sources/host) | data source |
| [vsphere_network.interface](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/data-sources/network) | data source |
| [vsphere_ovf_vm_template.this](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/data-sources/ovf_vm_template) | data source |
| [vsphere_resource_pool.this](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/data-sources/resource_pool) | data source |
| [vsphere_virtual_machine.source_image](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/data-sources/virtual_machine) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_annotation"></a> [annotation](#input\_annotation) | Optional vSphere annotation for the VM. | `string` | `"Managed by Terraform module terraform-vsphere-vmseries."` | no |
| <a name="input_bootstrap"></a> [bootstrap](#input\_bootstrap) | Optional VM-Series bootstrap generation and attachment settings.<br/><br/>Modes:<br/>- enabled=false: no bootstrap settings are applied.<br/>- enabled=true, create\_iso=true: module renders init-cfg.txt, optionally authcodes/bootstrap.xml, builds an ISO locally, uploads it with vsphere\_file, and attaches it.<br/>- enabled=true, create\_iso=false, local\_iso\_path set: module uploads the supplied local ISO and attaches it.<br/>- enabled=true, create\_iso=false, local\_iso\_path null: module assumes datastore\_path already exists and attaches it.<br/>- enabled=true, vapp\_properties\_enabled=true: module also renders native VM-Series guestinfo.pa\_vm.* vApp properties for OVF images that support them.<br/><br/>The default datastore\_path is <name>-bootstrap.iso at the datastore root. If you set a nested datastore\_path,<br/>pre-create the datastore folders or set create\_datastore\_directories=true only when those folders do not already exist. | <pre>object({<br/>    enabled                      = optional(bool, false)<br/>    create_iso                   = optional(bool, true)<br/>    attach_iso                   = optional(bool, true)<br/>    create_datastore_directories = optional(bool, false)<br/>    vapp_properties_enabled      = optional(bool, false)<br/>    work_dir                     = optional(string)<br/>    local_iso_path               = optional(string)<br/>    datastore_name               = optional(string)<br/>    datastore_path               = optional(string)<br/>    management_type              = optional(string, "static")<br/>    ip_address                   = optional(string)<br/>    default_gateway              = optional(string)<br/>    netmask                      = optional(string)<br/>    ipv6_address                 = optional(string)<br/>    ipv6_default_gateway         = optional(string)<br/>    hostname                     = optional(string)<br/>    panorama_server              = optional(string)<br/>    panorama_server_2            = optional(string)<br/>    template_stack               = optional(string)<br/>    device_group                 = optional(string)<br/>    dns_primary                  = optional(string)<br/>    dns_secondary                = optional(string)<br/>    op_command_modes             = optional(string)<br/>    op_cmd_dpdk_pkt_io           = optional(string)<br/>    plugin_op_commands           = optional(string)<br/>    dhcp_send_hostname           = optional(string)<br/>    dhcp_send_client_id          = optional(string)<br/>    dhcp_accept_server_hostname  = optional(string)<br/>    dhcp_accept_server_domain    = optional(string)<br/>    registration_pin_id          = optional(string)<br/>    additional_parameters        = optional(map(string), {})<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_bootstrap_auth_key"></a> [bootstrap\_auth\_key](#input\_bootstrap\_auth\_key) | Optional Panorama/plugin bootstrap value rendered as auth-key in /config/init-cfg.txt and native vApp properties when enabled. Use this for Software Firewall License plugin onboarding when Panorama returns an auth-key. | `string` | `null` | no |
| <a name="input_bootstrap_files"></a> [bootstrap\_files](#input\_bootstrap\_files) | Additional files to include in the generated bootstrap ISO, keyed by path relative to the bootstrap root.<br/>Paths must be under config/, license/, content/, software/, or plugins/. For each file, set exactly one of<br/>content, content\_base64, or source. | <pre>map(object({<br/>    content         = optional(string)<br/>    content_base64  = optional(string)<br/>    source          = optional(string)<br/>    file_permission = optional(string, "0600")<br/>  }))</pre> | `{}` | no |
| <a name="input_bootstrap_license_authcodes"></a> [bootstrap\_license\_authcodes](#input\_bootstrap\_license\_authcodes) | Optional VM-Series auth codes. With ISO bootstrap, this is rendered to /license/authcodes. With vApp bootstrap, it is rendered to guestinfo.pa\_vm.authcodes. | `string` | `null` | no |
| <a name="input_bootstrap_registration_pin_value"></a> [bootstrap\_registration\_pin\_value](#input\_bootstrap\_registration\_pin\_value) | Optional VM-Series auto-registration PIN value to include in the bootstrap ISO and native vApp properties when enabled. | `string` | `null` | no |
| <a name="input_bootstrap_vapp_options"></a> [bootstrap\_vapp\_options](#input\_bootstrap\_vapp\_options) | Optional value for the native guestinfo.pa\_vm.options vApp property when bootstrap.vapp\_properties\_enabled is true. | `string` | `null` | no |
| <a name="input_bootstrap_vm_auth_key"></a> [bootstrap\_vm\_auth\_key](#input\_bootstrap\_vm\_auth\_key) | Optional Panorama VM auth key rendered as vm-auth-key for workflows that explicitly require that key. | `string` | `null` | no |
| <a name="input_bootstrap_xml"></a> [bootstrap\_xml](#input\_bootstrap\_xml) | Optional full bootstrap.xml configuration content. Most Panorama-managed deployments should leave this null. | `string` | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Optional vSphere compute cluster name. Used to resolve the cluster root resource pool for vCenter deployments. | `string` | `null` | no |
| <a name="input_cpu_hot_add_enabled"></a> [cpu\_hot\_add\_enabled](#input\_cpu\_hot\_add\_enabled) | Enable CPU hot-add. | `bool` | `false` | no |
| <a name="input_custom_attributes"></a> [custom\_attributes](#input\_custom\_attributes) | vSphere custom attribute key/value pairs to assign to the VM. | `map(string)` | `{}` | no |
| <a name="input_datacenter"></a> [datacenter](#input\_datacenter) | vSphere datacenter name. | `string` | n/a | yes |
| <a name="input_datastore_name"></a> [datastore\_name](#input\_datastore\_name) | Datastore for the VM configuration and disks. | `string` | n/a | yes |
| <a name="input_disk_provisioning"></a> [disk\_provisioning](#input\_disk\_provisioning) | Disk provisioning mode for the OVA deployment. | `string` | `"thin"` | no |
| <a name="input_esxi_ssh_host"></a> [esxi\_ssh\_host](#input\_esxi\_ssh\_host) | Optional ESXi SSH host used only when ova.source\_image\_clone\_type is esxi. | `string` | `null` | no |
| <a name="input_esxi_ssh_password"></a> [esxi\_ssh\_password](#input\_esxi\_ssh\_password) | Optional ESXi SSH password used only when ova.source\_image\_clone\_type is esxi. | `string` | `null` | no |
| <a name="input_esxi_ssh_port"></a> [esxi\_ssh\_port](#input\_esxi\_ssh\_port) | ESXi SSH port used only when ova.source\_image\_clone\_type is esxi. | `number` | `22` | no |
| <a name="input_esxi_ssh_private_key"></a> [esxi\_ssh\_private\_key](#input\_esxi\_ssh\_private\_key) | Optional ESXi SSH private key contents used only when ova.source\_image\_clone\_type is esxi. | `string` | `null` | no |
| <a name="input_esxi_ssh_timeout"></a> [esxi\_ssh\_timeout](#input\_esxi\_ssh\_timeout) | ESXi SSH connection timeout used only when ova.source\_image\_clone\_type is esxi. | `string` | `"10m"` | no |
| <a name="input_esxi_ssh_user"></a> [esxi\_ssh\_user](#input\_esxi\_ssh\_user) | ESXi SSH user used only when ova.source\_image\_clone\_type is esxi. | `string` | `"root"` | no |
| <a name="input_extra_config"></a> [extra\_config](#input\_extra\_config) | Additional VMX extra\_config key/value pairs. | `map(string)` | `{}` | no |
| <a name="input_firmware"></a> [firmware](#input\_firmware) | Optional firmware override. If null, the OVA default is used. | `string` | `null` | no |
| <a name="input_folder"></a> [folder](#input\_folder) | Optional vSphere VM folder path. | `string` | `null` | no |
| <a name="input_force_power_off"></a> [force\_power\_off](#input\_force\_power\_off) | Force power off the VM when Terraform needs to destroy or reconfigure it and graceful shutdown is unavailable. | `bool` | `true` | no |
| <a name="input_hardware_version"></a> [hardware\_version](#input\_hardware\_version) | Optional VM virtual hardware version override. If null, standalone ESXi source-image deployments inherit the source image hardware version when available. | `number` | `null` | no |
| <a name="input_host_name"></a> [host\_name](#input\_host\_name) | Optional ESXi host name to target for placement. OVA deployment requires host\_name or host\_system\_id. | `string` | `null` | no |
| <a name="input_host_system_id"></a> [host\_system\_id](#input\_host\_system\_id) | Optional ESXi host managed object ID. Takes precedence over host\_name and avoids a host name lookup. | `string` | `null` | no |
| <a name="input_memory_hot_add_enabled"></a> [memory\_hot\_add\_enabled](#input\_memory\_hot\_add\_enabled) | Enable memory hot-add. | `bool` | `false` | no |
| <a name="input_memory_mb"></a> [memory\_mb](#input\_memory\_mb) | Optional memory override in MB. If null, the OVA default is used. | `number` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the VM-Series virtual machine in vSphere. | `string` | n/a | yes |
| <a name="input_network_interfaces"></a> [network\_interfaces](#input\_network\_interfaces) | Ordered VM-Series interface mappings to vSphere port groups.<br/><br/>ovf\_label is the OVF network name used during import. Set exactly one of network\_name or network\_id for each adapter.<br/>Some VM-Series OVAs expose one shared label such as "VM Network" for every adapter. In that case, repeat ovf\_label<br/>and set ovf\_mapping to the adapter name from the OVF, such as "Ethernet 1", "Ethernet 2", and "Ethernet 3". | <pre>list(object({<br/>    ovf_label    = string<br/>    network_name = optional(string)<br/>    network_id   = optional(string)<br/>    ovf_mapping  = optional(string)<br/>    adapter_type = optional(string, "vmxnet3")<br/>  }))</pre> | n/a | yes |
| <a name="input_num_cores_per_socket"></a> [num\_cores\_per\_socket](#input\_num\_cores\_per\_socket) | Optional cores-per-socket override. | `number` | `null` | no |
| <a name="input_num_cpus"></a> [num\_cpus](#input\_num\_cpus) | Optional CPU override. If null, the OVA default is used. | `number` | `null` | no |
| <a name="input_ova"></a> [ova](#input\_ova) | VM-Series image source and deployment options. Set exactly one of local\_path, remote\_url, source\_image\_name, or source\_image\_uuid.<br/>Use local\_path or remote\_url to import an OVF/OVA. Use source\_image\_name or source\_image\_uuid to clone an already-imported<br/>vSphere golden image VM/template and avoid uploading/importing the OVA again. | <pre>object({<br/>    local_path                              = optional(string)<br/>    remote_url                              = optional(string)<br/>    source_image_name                       = optional(string)<br/>    source_image_uuid                       = optional(string)<br/>    source_image_folder                     = optional(string)<br/>    source_image_clone_type                 = optional(string, "vcenter")<br/>    source_image_linked_clone               = optional(bool, false)<br/>    source_image_clone_timeout              = optional(number)<br/>    source_image_scsi_controller_scan_count = optional(number, 1)<br/>    source_image_nvme_controller_scan_count = optional(number, 1)<br/>    source_image_vmdk_path                  = optional(string)<br/>    source_image_disk_datastore_path        = optional(string)<br/>    source_image_disk_clone_type            = optional(string, "thin")<br/>    allow_unverified_ssl_cert               = optional(bool, false)<br/>    deployment_option                       = optional(string)<br/>    ip_protocol                             = optional(string, "IPV4")<br/>    ip_allocation_policy                    = optional(string, "STATIC_MANUAL")<br/>    enable_hidden_properties                = optional(bool, false)<br/>  })</pre> | n/a | yes |
| <a name="input_poweron_timeout"></a> [poweron\_timeout](#input\_poweron\_timeout) | Timeout in seconds to wait for the VM to power on. | `number` | `300` | no |
| <a name="input_resource_pool_id"></a> [resource\_pool\_id](#input\_resource\_pool\_id) | Optional resource pool managed object ID. Takes precedence over resource\_pool\_name and cluster\_name. | `string` | `null` | no |
| <a name="input_resource_pool_name"></a> [resource\_pool\_name](#input\_resource\_pool\_name) | Optional resource pool name or inventory path. If null, the cluster root resource pool is used when cluster\_name is set. | `string` | `null` | no |
| <a name="input_shutdown_wait_timeout"></a> [shutdown\_wait\_timeout](#input\_shutdown\_wait\_timeout) | Timeout in minutes to wait for a graceful guest shutdown before powering off. | `number` | `3` | no |
| <a name="input_storage_policy_id"></a> [storage\_policy\_id](#input\_storage\_policy\_id) | Optional VM storage policy ID to apply to the VM. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Set of vSphere tag IDs to attach to the VM. | `set(string)` | `[]` | no |
| <a name="input_vapp_properties"></a> [vapp\_properties](#input\_vapp\_properties) | Additional vApp/OVF property values to set on the VM. Use this for image-specific guestinfo properties not modeled by bootstrap settings. | `map(string)` | `{}` | no |
| <a name="input_wait_for_guest_ip_timeout"></a> [wait\_for\_guest\_ip\_timeout](#input\_wait\_for\_guest\_ip\_timeout) | Timeout in minutes to wait for a guest IP. VM-Series does not normally report this reliably before bootstrap, so the default is 0. | `number` | `0` | no |
| <a name="input_wait_for_guest_net_routable"></a> [wait\_for\_guest\_net\_routable](#input\_wait\_for\_guest\_net\_routable) | Require guest network routes before considering guest networking ready. | `bool` | `true` | no |
| <a name="input_wait_for_guest_net_timeout"></a> [wait\_for\_guest\_net\_timeout](#input\_wait\_for\_guest\_net\_timeout) | Timeout in minutes to wait for guest networking. VM-Series does not normally report this reliably before bootstrap, so the default is 0. | `number` | `0` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bootstrap_iso_datastore"></a> [bootstrap\_iso\_datastore](#output\_bootstrap\_iso\_datastore) | Datastore containing the bootstrap ISO, when attached. |
| <a name="output_bootstrap_iso_datastore_path"></a> [bootstrap\_iso\_datastore\_path](#output\_bootstrap\_iso\_datastore\_path) | Datastore-relative path of the bootstrap ISO, when attached. |
| <a name="output_id"></a> [id](#output\_id) | Terraform resource ID of the VM-Series virtual machine. |
| <a name="output_management_ip_address"></a> [management\_ip\_address](#output\_management\_ip\_address) | Static management IP address supplied through bootstrap, when management\_type is static. |
| <a name="output_moid"></a> [moid](#output\_moid) | vSphere managed object ID of the VM-Series virtual machine. |
| <a name="output_name"></a> [name](#output\_name) | Name of the VM-Series virtual machine. |
| <a name="output_network_interface_ids"></a> [network\_interface\_ids](#output\_network\_interface\_ids) | Ordered map of VM-Series adapter index to resolved vSphere network ID. |
| <a name="output_ovf_network_map"></a> [ovf\_network\_map](#output\_ovf\_network\_map) | Resolved OVF network label to vSphere network ID map. |
| <a name="output_uuid"></a> [uuid](#output\_uuid) | BIOS UUID of the VM-Series virtual machine. |
<!-- END_TF_DOCS -->
