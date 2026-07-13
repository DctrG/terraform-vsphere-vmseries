mock_provider "vsphere" {
  mock_data "vsphere_datacenter" {
    defaults = {
      id = "datacenter-1"
    }
  }

  mock_data "vsphere_compute_cluster" {
    defaults = {
      id               = "cluster-1"
      resource_pool_id = "resource-pool-root"
    }
  }

  mock_data "vsphere_host" {
    defaults = {
      id = "host-1"
    }
  }

  mock_data "vsphere_datastore" {
    defaults = {
      id = "datastore-1"
    }
  }

  mock_data "vsphere_resource_pool" {
    defaults = {
      id = "resource-pool-named"
    }
  }

  mock_data "vsphere_network" {
    defaults = {
      id = "network-1"
    }
  }

  mock_data "vsphere_ovf_vm_template" {
    defaults = {
      firmware        = "bios"
      guest_id        = "otherLinux64Guest"
      memory          = 8192
      num_cpus        = 2
      ovf_network_map = {}
      scsi_type       = "lsilogic"
    }
  }

  mock_data "vsphere_virtual_machine" {
    defaults = {
      id                      = "source-image-uuid"
      firmware                = "bios"
      guest_id                = "otherLinux64Guest"
      memory                  = 8192
      num_cpus                = 2
      scsi_type               = "lsilogic"
      network_interface_types = ["vmxnet3", "vmxnet3", "vmxnet3"]
      disks = [
        {
          label            = "Hard Disk 1"
          size             = 60
          eagerly_scrub    = false
          thin_provisioned = true
          unit_number      = 0
        }
      ]
    }
  }
}

mock_provider "local" {}

variables {
  datacenter     = "DC1"
  cluster_name   = "Cluster01"
  host_name      = "esxi-01.example.local"
  datastore_name = "vsanDatastore"

  ova = {
    local_path = "/tmp/PA-VM-ESX.ova"
  }

  network_interfaces = [
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 1", network_name = "PG-MGMT" },
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 2", network_name = "PG-UNTRUST" },
    { ovf_label = "VM Network", ovf_mapping = "Ethernet 3", network_name = "PG-TRUST" }
  ]
}

run "basic_ova_plan" {
  command = plan

  variables {
    name = "pa-vmseries-basic"
  }

  assert {
    condition     = vsphere_virtual_machine.this.name == "pa-vmseries-basic"
    error_message = "The VM name should come from var.name."
  }

  assert {
    condition     = vsphere_virtual_machine.this.memory == 8192
    error_message = "The VM should inherit memory from the OVF template when memory_mb is unset."
  }

  assert {
    condition     = output.bootstrap_iso_datastore_path == null
    error_message = "The basic deployment should not attach a bootstrap ISO."
  }
}

run "bootstrap_plan" {
  command = plan

  variables {
    name = "pa-vmseries-bootstrap"

    bootstrap = {
      enabled             = true
      create_iso          = true
      attach_iso          = true
      datastore_path      = "pa-vmseries-bootstrap-bootstrap.iso"
      management_type     = "static"
      ip_address          = "10.10.10.51"
      default_gateway     = "10.10.10.1"
      netmask             = "255.255.255.0"
      hostname            = "pa-vmseries-bootstrap"
      panorama_server     = "10.10.20.10"
      template_stack      = "TS-VMWARE"
      device_group        = "DG-VMWARE"
      dns_primary         = "10.10.10.10"
      plugin_op_commands  = "panorama-licensing-mode-on"
      registration_pin_id = "mock-registration-pin-id"
    }

    bootstrap_auth_key               = "mock-plugin-auth-key"
    bootstrap_vm_auth_key            = "mock-auth-key"
    bootstrap_registration_pin_value = "mock-registration-pin-value"
    bootstrap_files = {
      "content/README.txt" = {
        content = "mock content\n"
      }
      "plugins/mock-plugin.tgz" = {
        content_base64 = base64encode("mock plugin")
      }
    }
  }

  assert {
    condition     = output.management_ip_address == "10.10.10.51"
    error_message = "The management_ip_address output should expose the static bootstrap IP."
  }

  assert {
    condition     = output.bootstrap_iso_datastore_path == "pa-vmseries-bootstrap-bootstrap.iso"
    error_message = "The bootstrap ISO output should expose the configured datastore path."
  }

  assert {
    condition     = length(local_sensitive_file.bootstrap_files) == 2
    error_message = "The module should render caller-supplied bootstrap_files into the bootstrap ISO work directory."
  }
}

run "network_ids_plan" {
  command = plan

  variables {
    name = "pa-vmseries-network-ids"

    network_interfaces = [
      { ovf_label = "VM Network", ovf_mapping = "Ethernet 1", network_id = "network-mgmt" },
      { ovf_label = "VM Network", ovf_mapping = "Ethernet 2", network_id = "network-untrust" },
      { ovf_label = "VM Network", ovf_mapping = "Ethernet 3", network_id = "network-trust" }
    ]
  }

  assert {
    condition     = output.network_interface_ids["0"] == "network-mgmt"
    error_message = "The first network interface should use the caller-supplied network ID."
  }

  assert {
    condition     = output.ovf_network_map["VM Network"] == "network-mgmt"
    error_message = "The OVF network map should use the first adapter network for repeated OVF labels."
  }
}

run "bootstrap_vapp_properties_plan" {
  command = plan

  variables {
    name = "pa-vmseries-vapp-bootstrap"

    bootstrap = {
      enabled                 = true
      create_iso              = false
      attach_iso              = false
      vapp_properties_enabled = true
      management_type         = "dhcp-client"
      hostname                = "pa-vmseries-vapp-bootstrap"
      panorama_server         = "10.10.20.10"
      template_stack          = "TS-VMWARE"
      device_group            = "DG-VMWARE"
      registration_pin_id     = "mock-registration-pin-id"
    }

    bootstrap_vm_auth_key            = "mock-auth-key"
    bootstrap_registration_pin_value = "mock-registration-pin-value"
    bootstrap_license_authcodes      = "mock-authcode"
    bootstrap_vapp_options           = "plugin-op-commands=panorama-licensing-mode-on"
  }

  assert {
    condition     = length(vsphere_virtual_machine.this.vapp) == 1
    error_message = "vApp properties should be configured when bootstrap.vapp_properties_enabled is true."
  }

  assert {
    condition     = nonsensitive(vsphere_virtual_machine.this.vapp[0].properties["guestinfo.pa_vm.hostname"]) == "pa-vmseries-vapp-bootstrap"
    error_message = "The vApp hostname property should be generated from bootstrap.hostname."
  }

  assert {
    condition     = nonsensitive(vsphere_virtual_machine.this.vapp[0].properties["guestinfo.pa_vm.vm-auth-key"]) == "mock-auth-key"
    error_message = "The vApp VM auth key property should be generated from bootstrap_vm_auth_key."
  }

  assert {
    condition     = nonsensitive(vsphere_virtual_machine.this.vapp[0].properties["guestinfo.pa_vm.vm-series-auto-registration-pin-value"]) == "mock-registration-pin-value"
    error_message = "The vApp registration PIN value property should be generated from bootstrap_registration_pin_value."
  }

  assert {
    condition     = nonsensitive(vsphere_virtual_machine.this.vapp[0].properties["guestinfo.pa_vm.options"]) == "plugin-op-commands=panorama-licensing-mode-on"
    error_message = "The vApp options property should be generated from bootstrap_vapp_options."
  }
}

run "source_image_clone_plan" {
  command = plan

  variables {
    name = "pa-vmseries-source-image"

    ova = {
      source_image_name = "templates/PA-VM-Series-Golden"
    }
  }

  assert {
    condition     = vsphere_virtual_machine.this.clone[0].template_uuid == "source-image-uuid"
    error_message = "The VM should clone from the selected source image when source_image_name is set."
  }

  assert {
    condition     = length(vsphere_virtual_machine.this.ovf_deploy) == 0
    error_message = "The VM should not run ovf_deploy when cloning from a source image."
  }

  assert {
    condition     = vsphere_virtual_machine.this.disk[0].size == 60
    error_message = "The VM should inherit disk sizing from the source image."
  }
}

run "standalone_esxi_resource_pool_id_plan" {
  command = plan

  variables {
    name             = "pa-vmseries-standalone"
    cluster_name     = null
    resource_pool_id = "resource-pool-standalone"
  }

  assert {
    condition     = vsphere_virtual_machine.this.resource_pool_id == "resource-pool-standalone"
    error_message = "Standalone ESXi deployments should support a caller-supplied resource pool ID."
  }
}

run "host_system_id_plan" {
  command = plan

  variables {
    name           = "pa-vmseries-host-id"
    host_name      = null
    host_system_id = "host-123"
  }

  assert {
    condition     = vsphere_virtual_machine.this.host_system_id == "host-123"
    error_message = "The VM should use the caller-supplied host managed object ID when host_system_id is set."
  }
}
