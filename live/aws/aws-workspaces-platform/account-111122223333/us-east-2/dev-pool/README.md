# WorkSpaces - Dev Pool

## Purpose
Deploy a dedicated **WorkSpaces Pool** for Dev workloads using:
- Pool name: `workspaces-platform-pilot-dev-pool-v1`
- Bundle name: `workspaces-platform-pilot-dev-4xlarge-v1`
- Bundle ID: `wsb-00000002`

## Configuration Notes
- Bundle is sourced from `common.hcl`:
  - `default_bundles.dev = wsb-00000002`
- Pooled directory is sourced from `common.hcl`:
  - `pool_directory_id` (`wsd-00000000`)
- SAML metadata XML secret ARN must be set in `terragrunt.hcl`.

## Runbook
```bash
# From repo root:
./preflight.sh

cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/dev-pool
terragrunt init
terragrunt plan
terragrunt apply
```

## Prerequisites
See [PREREQUISITES.md](../../../../../../PREREQUISITES.md) for setup steps on macOS, Windows, and Linux.
