# Changelog

## v0.1.0

- Initial module skeleton.
- Deploy VM-Series OVA with `vsphere_virtual_machine.ovf_deploy`.
- Map OVF network labels to vSphere networks.
- Support vCenter and standalone ESXi placement with cluster, resource pool, host name, or host managed object ID inputs.
- Support cloning from an already-imported VM-Series golden image.
- Optional bootstrap package generation with `init-cfg.txt`, license authcodes, `bootstrap.xml`, and additional caller-supplied files.
- Optional bootstrap ISO build, upload, and CD-ROM attachment.
- Optional native VM-Series `guestinfo.pa_vm.*` vApp bootstrap properties.
