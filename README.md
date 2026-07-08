# terraform-vsphere-vmseries

Terraform module for deploying a Palo Alto Networks VM-Series firewall OVA into VMware vSphere / VMware private cloud.

This module is intentionally focused on the infrastructure side of a private-cloud VM-Series deployment:

- Deploy a VM-Series OVA with the VMware vSphere Terraform provider.
- Map OVF network labels to vSphere port groups.
- Optionally generate a PAN-OS bootstrap package.
- Optionally build and upload a bootstrap ISO to a datastore.
- Optionally attach the bootstrap ISO as a vSphere CD-ROM.

Panorama / PAN-OS policy, templates, device groups, licensing workflows, and commit operations should be handled separately with Panorama, the PAN-OS API, Ansible, CI/CD, or the Palo Alto Networks PAN-OS Terraform provider.

## Status

Initial publishable module skeleton. Validate in your lab before using in production.

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

## Testing

Run these checks before publishing or opening a pull request:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
```

The native Terraform tests use mocked providers, so they do not require a live vCenter or a real VM-Series OVA.

## Basic OVA deployment

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
    local_path = "/opt/images/PA-VM-ESX-11.0.0.ova"
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

> PA-VM-ESX-11.0.0 exposes one OVF network label, `VM Network`, and three adapters named `Ethernet 1`, `Ethernet 2`, and `Ethernet 3`. Other image versions can vary, so inspect the OVA/OVF descriptor if deployment fails with a network mapping error.

## Panorama bootstrap example

```hcl
module "vmseries" {
  source = "github.com/YOUR_ORG/terraform-vsphere-vmseries?ref=v0.1.0"

  name           = "pa-vmseries-01"
  datacenter     = "DC1"
  cluster_name   = "Cluster01"
  host_name      = "esxi-01.example.local"
  datastore_name = "vsanDatastore"

  ova = {
    local_path = "/opt/images/PA-VM-ESX-11.0.0.ova"
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

## Publishing to the Terraform Registry

1. Push this repository to GitHub with the name `terraform-vsphere-vmseries`.
2. Add a semantic version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

3. In Terraform Registry, publish the GitHub repository as a module.
4. The module will appear as:

```hcl
module "vmseries" {
  source  = "YOUR_NAMESPACE/vmseries/vsphere"
  version = "0.1.0"
}
```

## Recommended production pattern

For production, prefer a two-stage pipeline:

1. Platform pipeline: deploy the VM-Series appliance with this module.
2. Security pipeline: use Panorama / PAN-OS automation to assign the device to policy, templates, licensing, content updates, and commits.

This keeps vSphere lifecycle and firewall policy lifecycle separated.
