# WorkSpaces - SOC Pool

## Purpose
Deploy a dedicated **WorkSpaces Pool** for SOC workloads using:
- Pool name: `workspaces-platform-pilot-soc-pool-v1`
- Bundle name: `workspaces-platform-pilot-soc-bundle-v1`
- Bundle ID: `wsb-00000001`

This deployment is implemented with Terraform/Terragrunt using:
- `shadbury/workspaces-pooled/aws` Terraform Registry module (`v1.0.3`)
- `hashicorp/aws` provider resources used inside that module

## Configuration
This unit is configured for:
- Minimum sessions: `2`
- Maximum sessions: `10`
- Desired sessions: `2`
- Running mode: `AUTO_STOP`
- Maximum session duration: `480` minutes
- Disconnect timeout: `60` minutes
- Idle timeout: `30` minutes
- Application settings persistence: `ENABLED`

## Important Prerequisite
WorkSpaces Pools in this project use the shared directory ID:
- `d-0000000000` (`workspaces-platform.local`)

This value is set in:
- `pool_directory_id` in `live/aws/aws-workspaces-platform/account-111122223333/us-east-1/common.hcl`

This keeps the pool deployment aligned to the same `workspaces-platform.local` directory service used by personal WorkSpaces.

You must also store SAML metadata XML in Secrets Manager and set:
- `saml_xml_secret_arn` in `terragrunt.hcl`

The referenced secret string must contain raw XML metadata content.

## Runbook
```bash
# From repo root:
./preflight.sh

cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/soc-pool
terragrunt init
terragrunt plan
terragrunt apply
```

## Outputs
- Pool ID
- Pool ARN
- Min/Max registered scaling bounds

## Prerequisites
See [PREREQUISITES.md](../../../../../../PREREQUISITES.md) for setup steps on macOS, Windows, and Linux.
