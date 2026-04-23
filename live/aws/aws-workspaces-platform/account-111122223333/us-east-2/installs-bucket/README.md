# WorkSpaces Installs Bucket

## Purpose
Provision the S3 bucket `workspaces-platform-pilot-installs` for install media.

## Structure
- `terragrunt.hcl` defines inputs and backend state key `installs-bucket.tfstate`.

## Runbook
```bash
# From repo root:
./preflight.sh

cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/installs-bucket
terragrunt init
terragrunt plan
terragrunt apply
```


## Prerequisites
See [PREREQUISITES.md](../../../../../../PREREQUISITES.md) for setup steps on macOS, Windows, and Linux.
