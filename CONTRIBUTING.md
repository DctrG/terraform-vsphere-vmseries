# Contributing

Before opening a pull request:

1. Run `terraform fmt -check -recursive`.
2. Run `terraform init -backend=false` in the root module.
3. Run `terraform validate` in the root module.
4. Run `terraform test`.
5. Initialize and validate each changed configuration under `examples/`.
6. Validate infrastructure-affecting changes in a non-production vSphere environment before relying on them in production.

Add tests for new behavior and for invalid inputs that could delete, overwrite, or expose infrastructure. Keep the public input/output contract backward compatible unless the change is intentionally released as a new major version.

Do not commit OVA/VMDK files, generated ISO files, state, plans, provider lock files, populated `.tfvars`, credentials, auth keys, or license material. Follow [SECURITY.md](SECURITY.md) for vulnerability reports and [RELEASING.md](RELEASING.md) for releases.
