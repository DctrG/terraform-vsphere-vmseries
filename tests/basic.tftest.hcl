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
      enabled         = true
      create_iso      = true
      attach_iso      = true
      datastore_path  = "vmseries-bootstrap/pa-vmseries-bootstrap/bootstrap.iso"
      management_type = "static"
      ip_address      = "10.10.10.51"
      default_gateway = "10.10.10.1"
      netmask         = "255.255.255.0"
      hostname        = "pa-vmseries-bootstrap"
      panorama_server = "10.10.20.10"
      template_stack  = "TS-VMWARE"
      device_group    = "DG-VMWARE"
      dns_primary     = "10.10.10.10"
    }

    bootstrap_vm_auth_key = "mock-auth-key"
  }

  assert {
    condition     = output.management_ip_address == "10.10.10.51"
    error_message = "The management_ip_address output should expose the static bootstrap IP."
  }

  assert {
    condition     = output.bootstrap_iso_datastore_path == "vmseries-bootstrap/pa-vmseries-bootstrap/bootstrap.iso"
    error_message = "The bootstrap ISO output should expose the configured datastore path."
  }
}
