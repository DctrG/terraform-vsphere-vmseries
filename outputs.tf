output "id" {
  description = "Terraform resource ID of the VM-Series virtual machine."
  value       = vsphere_virtual_machine.this.id
}

output "uuid" {
  description = "BIOS UUID of the VM-Series virtual machine."
  value       = vsphere_virtual_machine.this.uuid
}

output "moid" {
  description = "vSphere managed object ID of the VM-Series virtual machine."
  value       = vsphere_virtual_machine.this.moid
}

output "name" {
  description = "Name of the VM-Series virtual machine."
  value       = vsphere_virtual_machine.this.name
}

output "management_ip_address" {
  description = "Static management IP address supplied through bootstrap, when management_type is static."
  value       = local.bootstrap_management_ip
}

output "bootstrap_iso_datastore" {
  description = "Datastore containing the bootstrap ISO, when attached."
  value       = local.bootstrap_attach_iso ? local.bootstrap_datastore_name : null
}

output "bootstrap_iso_datastore_path" {
  description = "Datastore-relative path of the bootstrap ISO, when attached."
  value       = local.bootstrap_attach_iso ? local.bootstrap_datastore_path : null
}

output "ovf_network_map" {
  description = "Resolved OVF network label to vSphere network ID map."
  value       = local.ovf_network_map
}
