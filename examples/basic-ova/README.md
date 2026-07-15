# Basic OVA deployment

This example imports a VM-Series OVA into vSphere and maps its management and dataplane adapters to existing vSphere networks. It is intended for a first deployment or for creating a clean golden image.

## Prerequisites

- Terraform 1.5 or later.
- vSphere credentials with permission to read inventory and create virtual machines.
- An ESXi host, datastore, resource pool or cluster, and target port groups.
- A VM-Series OVA accessible from the Terraform runner.

## Usage

1. Create a local `terraform.tfvars` from `terraform.tfvars.example` and set environment-specific values.
2. Run `terraform init`.
3. Review `terraform plan` before applying.

The example uses `source = "../../"` so it can validate directly from a source checkout. When moving the configuration into another repository, use the Registry source `DctrG/vmseries/vsphere` and pin an appropriate module version.

Do not commit credentials, OVA files, state, or populated `.tfvars` files.
