# Contributing

Before opening a pull request:

1. Run `terraform fmt -recursive`.
2. Run `terraform init -backend=false` in the root module.
3. Run `terraform validate` in the root module.
4. Validate the examples in a lab vSphere environment.

Do not commit OVA files, ISO files, state files, or `.tfvars` files containing credentials.
