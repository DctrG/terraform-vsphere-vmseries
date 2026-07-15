# Changelog

## Unreleased

## v0.1.0 - 2026-07-15

- Validate VMFS paths, numeric capacity and timeout values, bootstrap keys, and single-line credentials before provider operations.
- Build bootstrap media with environment-based shell inputs and restrictive local permissions.
- Refuse to overwrite an existing standalone ESXi destination VMDK and clean up only a partial clone from the current attempt.
- Ensure the Panorama-generated plugin auth key precedes `plugin-op-commands` in `init-cfg.txt`.
- Build generated bootstrap ISOs outside the source tree before atomically moving them into place.
- Allow the Panorama example to preserve a PAN-OS hostname while using a fresh vSphere VM and datastore identity.
- Add negative validation tests, pinned GitHub Actions CI, example documentation, a security policy, and a Registry release checklist.

- Initial module skeleton.
- Deploy VM-Series OVA with `vsphere_virtual_machine.ovf_deploy`.
- Map OVF network labels to vSphere networks.
- Support vCenter and standalone ESXi placement with cluster, resource pool, host name, or host managed object ID inputs.
- Support cloning from an already-imported VM-Series golden image.
- Optional bootstrap package generation with `init-cfg.txt`, license authcodes, `bootstrap.xml`, and additional caller-supplied files.
- Optional bootstrap ISO build, upload, and CD-ROM attachment.
- Optional native VM-Series `guestinfo.pa_vm.*` vApp bootstrap properties.
