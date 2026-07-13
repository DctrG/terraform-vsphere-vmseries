# Contributing

Before opening a pull request:

1. Run `terraform fmt -recursive`.
2. Run `terraform init -backend=false` in the root module.
3. Run `terraform validate` in the root module.
4. Run `terraform test`.
5. Validate changed examples in a non-production vSphere environment before relying on them in production.

Do not commit OVA files, ISO files, state files, or `.tfvars` files containing credentials.
