# Security policy

## Supported versions

Until the module reaches 1.0, security fixes are provided for the latest published minor version. Consumers should pin a compatible version constraint and update promptly when a security release is available.

## Reporting a vulnerability

Use GitHub's **Report a vulnerability** feature for private disclosure. If private vulnerability reporting is unavailable, contact the repository owner through GitHub before sharing sensitive details publicly.

Include the affected module version, Terraform and provider versions, deployment mode, impact, and a minimal reproduction. Remove credentials, auth keys, license data, private network details, state files, plans, generated bootstrap media, and proprietary VM images.

Do not open a public issue for an unpatched vulnerability or include secrets in logs or attachments.

## Sensitive data

Several inputs are marked sensitive, but Terraform must still pass them to providers or provisioners and may retain them in state, local bootstrap files, vSphere VM configuration, or uploaded bootstrap media. Use encrypted remote state, a trusted runner, restricted filesystem permissions, short-lived bootstrap credentials, and controlled datastore access.
