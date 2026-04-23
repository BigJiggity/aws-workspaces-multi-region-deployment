# WorkSpaces - Standard Pool

## Purpose
Deploy a dedicated **WorkSpaces Pool** for Standard workloads.

## Placeholder Notes
- Bundle is sourced from `common.hcl`:
  - `default_bundles.standard`
- Pooled directory is sourced from `common.hcl`:
  - `pool_directory_id` (`wsd-00000000`)
- SAML metadata XML secret ARN must be set in `terragrunt.hcl`.

## Runbook
```bash
# From repo root:
./preflight.sh

cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/standard-pool
terragrunt init
terragrunt plan
terragrunt apply
```

## Prerequisites
See [PREREQUISITES.md](../../../../../../PREREQUISITES.md) for setup steps on macOS, Windows, and Linux.
