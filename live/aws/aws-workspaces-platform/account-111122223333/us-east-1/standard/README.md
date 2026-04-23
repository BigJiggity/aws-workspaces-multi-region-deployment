# WorkSpaces - Standard Tier

## Purpose
Deploy Standard tier WorkSpaces only.

## Structure
- `terragrunt.hcl` defines inputs and backend state key `standard.tfstate`.

## Runbook
```bash
# From repo root:
./preflight.sh

cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/standard
terragrunt init
terragrunt plan
terragrunt apply
```

## Notes
- Add users with `./run-add-workspace.sh` (or `.\run-add-workspace.ps1`) and select the **standard** tier.
- Shared settings (directory, subnets, backend) live in `../common.hcl`.


## Prerequisites
See [PREREQUISITES.md](../../../../../../PREREQUISITES.md) for setup steps on macOS, Windows, and Linux.
