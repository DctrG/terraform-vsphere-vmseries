# terraform-vsphere-vmseries

Terraform module for deploying a Palo Alto Networks VM-Series firewall OVA into VMware vSphere / VMware private cloud.

This module is intentionally focused on the infrastructure side of a private-cloud VM-Series deployment:

- Deploy a VM-Series OVA with the VMware vSphere Terraform provider.
- Map OVF network labels to vSphere port groups.
- Optionally generate a PAN-OS bootstrap package.
- Optionally build and upload a bootstrap ISO to a datastore.
- Optionally attach the bootstrap ISO as a vSphere CD-ROM.

Panorama / PAN-OS policy, templates, device groups, licensing workflows, and commit operations should be handled separately with Panorama, the PAN-OS API, Ansible, CI/CD, or the Palo Alto Networks PAN-OS Terraform provider.

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

## Using with real vSphere

Prepare these vCenter objects before running `terraform plan`:

- A datacenter, compute cluster, ESXi host, and datastore visible to the Terraform user.
- One VM folder if you set `folder`; the module does not create folders.
- Port groups or NSX segments for management and dataplane adapters.
- A local OVA path visible to the Terraform runner, or an HTTPS URL in `ova.remote_url`.
- For bootstrap ISO generation, one supported ISO builder on the Terraform runner.

Use the helper script to inspect the OVA labels:

```bash
scripts/inspect-ova-networks.sh /path/to/PA-VM-ESX.ova
```

Many VM-Series ESXi OVAs expose one OVF network label, such as `VM Network`, and adapters named `Ethernet 1`, `Ethernet 2`, and `Ethernet 3`. Map those adapters in order: management, untrust, then trust, unless your design uses a different interface order.

If your vCenter has duplicate port group names, pass `network_id` instead of `network_name`:

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
  source = "github.com/YOUR_ORG/terraform-vsphere-vmseries?ref=v0.1.0"

  name           = "pa-vmseries-01"
  datacenter     = "DC1"
  cluster_name   = "Cluster01"
  host_name      = "esxi-01.example.local"
  datastore_name = "vsanDatastore"

  ova = {
    local_path = "/opt/images/PA-VM-ESX.ova"
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

> VM-Series OVA labels can vary by PAN-OS image and build. Inspect the OVA/OVF descriptor if deployment fails with a network mapping error.

## Panorama Bootstrap

```hcl
module "vmseries" {
  source = "github.com/YOUR_ORG/terraform-vsphere-vmseries?ref=v0.1.0"

  name           = "pa-vmseries-01"
  datacenter     = "DC1"
  cluster_name   = "Cluster01"
  host_name      = "esxi-01.example.local"
  datastore_name = "vsanDatastore"

  ova = {
    local_path = "/opt/images/PA-VM-ESX.ova"
  }

  network_interfaces = [
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 1", network_name = "PG-MGMT" },
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 2", network_name = "PG-UNTRUST" },
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 3", network_name = "PG-TRUST" }
  ]

  bootstrap = {
    enabled         = true
    create_iso      = true
    attach_iso      = true
    datastore_path  = "vmseries-bootstrap/pa-vmseries-01/bootstrap.iso"

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
  }

  bootstrap_vm_auth_key     = var.bootstrap_vm_auth_key
  bootstrap_license_authcodes = var.bootstrap_license_authcodes
}
```

## Inputs

Key inputs are below. See `variables.tf` for the full contract.

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name` | VM name in vCenter | `string` | required |
| `datacenter` | vSphere datacenter | `string` | required |
| `cluster_name` | Compute cluster | `string` | required |
| `host_name` | ESXi host for OVA deployment | `string` | required |
| `datastore_name` | VM datastore | `string` | required |
| `ova` | OVA source and deployment options | `object` | required |
| `network_interfaces` | Ordered VM-Series adapter mappings to vSphere port groups | `list(object)` | required |
| `custom_attributes` | vSphere custom attribute key/value pairs | `map(string)` | `{}` |
| `tags` | vSphere tag IDs to attach to the VM | `set(string)` | `[]` |
| `storage_policy_id` | Optional VM storage policy ID | `string` | `null` |
| `bootstrap` | Bootstrap ISO generation/upload/attach settings | `object` | disabled |
| `bootstrap_vm_auth_key` | Panorama VM auth key | `string` | `null` |
| `bootstrap_license_authcodes` | `/license/authcodes` content | `string` | `null` |
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

Sensitive values such as `bootstrap_vm_auth_key`, `bootstrap_registration_pin_value`, `bootstrap_license_authcodes`, and `bootstrap_xml` are marked sensitive, but they are still written to the local bootstrap work directory and Terraform state will include enough metadata to manage the resources. Use a secure runner and encrypted remote state.

## Non-goals

This module does not:

- Generate Panorama VM auth keys.
- Create Panorama template stacks or device groups.
- Commit Panorama or PAN-OS configuration.
- Register licenses through CSP.
- Configure NSX-T service insertion.
- Implement autoscaling.

## Recommended production pattern

For production, prefer a two-stage pipeline:

1. Platform pipeline: deploy the VM-Series appliance with this module.
2. Security pipeline: use Panorama / PAN-OS automation to assign the device to policy, templates, licensing, content updates, and commits.

This keeps vSphere lifecycle and firewall policy lifecycle separated.
