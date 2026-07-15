# Panorama bootstrap

This example deploys a VM-Series firewall from a clean golden image and creates the `init-cfg.txt` bootstrap ISO used by Panorama's Software Firewall License plugin. It supports native vCenter cloning and standalone ESXi VMDK copying.

## Credential Flow

Keep the two plugin credentials in their proper locations:

1. Put the Flex Credits/CSP license auth code in Panorama's **Bootstrap Definition**.
2. Create and commit a Panorama **License Manager** that selects that Bootstrap Definition, the device group, and the template stack.
3. Open **Show Bootstrap Parameters** for the License Manager.
4. Put Panorama's generated `auth-key` in `bootstrap_auth_key`.
5. Keep `bootstrap_plugin_op_commands = "panorama-licensing-mode-on"`.

For this workflow, leave `bootstrap_vm_auth_key`, `bootstrap_license_authcodes`, and registration PIN variables unset. The generated `auth-key` replaces a manually generated VM auth key; it is not the Flex Credits/CSP license auth code.

The example renders these plugin-specific lines in `/config/init-cfg.txt`:

```text
auth-key=<Panorama-generated value>
plugin-op-commands=panorama-licensing-mode-on
```

## Prerequisites

- All prerequisites from the [root module README](../../README.md).
- A clean, unlicensed VM-Series golden image.
- A compatible Panorama Software Firewall License plugin.
- A committed Panorama Bootstrap Definition and License Manager.
- A Panorama address reachable from the firewall management interface.
- `genisoimage`, `mkisofs`, `xorrisofs`, or macOS `hdiutil` on the Terraform runner.

## Usage

1. Create `terraform.tfvars` from `terraform.tfvars.example` and set the vSphere, image, network, and management values.
2. Copy the License Manager's current generated `auth-key` into `bootstrap_auth_key`; generate a fresh value in Panorama if an older key has expired.
3. If Panorama is behind NAT, set `panorama_server` to the public IP or DNS name reachable from the firewall, even when **Show Bootstrap Parameters** displays a private address.
4. Run `terraform init` and review `terraform plan`.
5. Apply only after confirming the image, destination VMDK, datastore ISO path, and network mappings.
6. Allow first boot, license installation, and any management-plane restart to complete.
7. Verify the firewall under the License Manager's **Show Devices**, then in Panorama Managed Devices.
8. Commit Panorama if registration added the firewall serial number to candidate configuration.

If onboarding stalls, compare the generated auth key, device group, template stack, plugin command, and Panorama address with **Show Bootstrap Parameters**. On Panorama, `show plugins sw_fw_license panorama-api-requests` reports the licensing API calls.

Refer to Palo Alto Networks' [Panorama-based Software Firewall License Management documentation](https://docs.paloaltonetworks.com/vm-series/activation-and-onboarding/vm-series-firewall-licensing/use-panorama-based-software-firewall-license-management) for the current plugin requirements and Panorama-side procedure.

The example uses `source = "../../"` for validation from a source checkout. In another repository, use `DctrG/vmseries/vsphere` and pin the intended module version.

Do not commit credentials, auth keys, state, generated bootstrap media, or populated `.tfvars` files.
