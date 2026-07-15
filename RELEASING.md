# Releasing

The public Terraform Registry discovers this module from the public GitHub repository `DctrG/terraform-vsphere-vmseries` and semantic-version tags.

## Release checklist

1. Confirm the working tree contains no state, plans, populated `.tfvars`, credentials, auth keys, generated ISO/OVA/VMDK files, or provider lock files.
2. Run `terraform fmt -check -recursive`, `terraform validate`, and `terraform test`.
3. Initialize and validate both configurations under `examples/`.
4. Confirm the GitHub Actions workflow passes on the release commit.
5. Move the relevant entries from `Unreleased` in `CHANGELOG.md` into the target version section.
6. Review the public input/output contract and choose the version according to Semantic Versioning.
7. Create an annotated tag such as `v0.1.0` and push the tag without moving or replacing previously published tags.
8. For the first release, sign in to the Terraform Registry, choose **Upload module**, and select this repository. Later valid version tags are detected by the Registry webhook.
9. Verify the Registry page renders the README, providers, inputs, outputs, examples, and source link correctly.

The first Registry publication requires at least one valid semantic-version tag. Do not create the tag until the release commit is on the default branch and CI is green.
