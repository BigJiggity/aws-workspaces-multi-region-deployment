# AWS WorkSpaces Multi-Region Deployment (Terragrunt + Terraform)

This repository provides a configurable, standalone framework to deploy AWS WorkSpaces and related infrastructure across multiple AWS regions using Terragrunt and Terraform.

## What This Project Delivers
- Terragrunt repository layout aligned to best practices (`root.hcl`, `live/`, `modules/source/`).
- Multi-region deployment scaffold with account/region pathing under `live/aws/...`.
- Config-driven setup via `config/deployment.env` and `scripts/configure-project.sh`.
- Preflight validation for tools, AWS identity, backend access, and region layout.
- AWS Well-Architected-aligned guidance and operational runbooks.

## Prerequisites
- Terraform `>= 1.5`.
- Terragrunt.
- AWS CLI v2.
- Bash (for `scripts/*.sh`).
- AWS credentials with access for the target account/regions.
- IAM permissions for:
  - S3, DynamoDB, KMS (Terraform/Terragrunt backend).
  - WorkSpaces and related services used by selected stacks.
- Backend resources available in `PRIMARY_REGION` (existing or deployed via `backend/<region>`):
  - S3 state bucket.
  - DynamoDB lock table.
  - KMS key/alias for state encryption.
- WorkSpaces environment inputs ready for your target regions:
  - Directory IDs (`DIRECTORY_ID`, `POOL_DIRECTORY_ID`).
  - Supported WorkSpaces subnets/AZ mappings.
  - Bundle IDs and pool networking inputs.

Detailed prerequisites guide: [`docs/PREREQUISITES.md`](docs/PREREQUISITES.md)

## Quickstart
1. Copy the config template:

```bash
cp config/deployment.env.example config/deployment.env
```

2. Update `config/deployment.env` with your organization/account/region values.

3. Apply repository configuration:

```bash
./scripts/configure-project.sh --config config/deployment.env
```

4. Deploy backend (if backend resources do not already exist):

```bash
cd backend/<PRIMARY_REGION>
terraform init
terraform apply
```

5. Run preflight checks:

```bash
./scripts/preflight.sh --config config/deployment.env
```

6. Deploy selected Terragrunt units from `live/aws/...`.

## Repository Layout
- `root.hcl`: global Terragrunt defaults.
- `live/`: deployable Terragrunt units and hierarchy metadata.
- `modules/source/aws/`: Terraform implementations.
- `backend/`: Terraform backend bootstrap (S3 + DynamoDB + KMS).
- `scripts/`: configuration, preflight, and workflow automation scripts.
- `docs/`: architecture, standards, and Well-Architected documentation.

## Configuration and Operations
- Main config template: [`config/deployment.env.example`](config/deployment.env.example)
- Configure repository for your environment: [`scripts/configure-project.sh`](scripts/configure-project.sh)
- Validate prerequisites and layout: [`scripts/preflight.sh`](scripts/preflight.sh)
- Add/deploy WorkSpaces interactively: [`scripts/run-add-workspace.sh`](scripts/run-add-workspace.sh)
- Cleanup errored WorkSpaces: [`scripts/cleanup-workspaces.sh`](scripts/cleanup-workspaces.sh)

## Documentation and Runbook Index

### Core Documentation
- [`docs/PROJECT_SUMMARY.md`](docs/PROJECT_SUMMARY.md)
- [`docs/PREREQUISITES.md`](docs/PREREQUISITES.md)
- [`docs/STYLE_GUIDE.md`](docs/STYLE_GUIDE.md)
- [`docs/WELL_ARCHITECTED_ALIGNMENT.md`](docs/WELL_ARCHITECTED_ALIGNMENT.md)
- [`docs/WELL_ARCHITECTED_CHECKLIST.md`](docs/WELL_ARCHITECTED_CHECKLIST.md)
- [`docs/Cloud-Tagging-Standards.md`](docs/Cloud-Tagging-Standards.md)
- [`backend/README.md`](backend/README.md)
- [`live/README.md`](live/README.md)

### WorkSpaces Platform Unit Runbooks
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-1/standard/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-1/standard/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-1/soc/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-1/soc/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-1/dev/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-1/dev/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-1/standard-pool/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-1/standard-pool/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-1/soc-pool/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-1/soc-pool/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-1/dev-pool/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-1/dev-pool/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-1/installs-bucket/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-1/installs-bucket/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-2/standard/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-2/standard/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-2/soc/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-2/soc/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-2/dev/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-2/dev/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-2/standard-pool/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-2/standard-pool/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-2/soc-pool/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-2/soc-pool/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-2/dev-pool/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-2/dev-pool/README.md)
- [`live/aws/aws-workspaces-platform/account-111122223333/us-east-2/installs-bucket/README.md`](live/aws/aws-workspaces-platform/account-111122223333/us-east-2/installs-bucket/README.md)

### WorkSpaces VDI Architecture and Runbooks
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/RUNBOOK-User-Provisioning.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/RUNBOOK-User-Provisioning.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/RUNBOOK-User-Provisioning.confluence`](modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/RUNBOOK-User-Provisioning.confluence)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/VDI-Architecture-Document.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/VDI-Architecture-Document.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/SECURITY_GROUPS.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/SECURITY_GROUPS.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/PRE_DEPLOYMENT_ANALYSIS.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/PRE_DEPLOYMENT_ANALYSIS.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/FINAL_DEPLOYMENT_SUMMARY.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/FINAL_DEPLOYMENT_SUMMARY.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/CRITICAL_ISSUES.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/docs/CRITICAL_ISSUES.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/us-east-1/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/us-east-1/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/us-east-1/ansible/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/us-east-1/ansible/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/us-east-2/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/us-east-2/README.md)

### Active Directory Documentation and Runbooks
- [`modules/source/aws/aws-ActiveDirectory/account-111122223333/README.md`](modules/source/aws/aws-ActiveDirectory/account-111122223333/README.md)
- [`modules/source/aws/aws-ActiveDirectory/account-111122223333/ansible/README.md`](modules/source/aws/aws-ActiveDirectory/account-111122223333/ansible/README.md)
- [`modules/source/aws/aws-ActiveDirectory/account-111122223333/ansible/playbooks/user-management/README.md`](modules/source/aws/aws-ActiveDirectory/account-111122223333/ansible/playbooks/user-management/README.md)
- [`modules/source/aws/aws-ActiveDirectory/account-111122223333/modules/secrets/README.md`](modules/source/aws/aws-ActiveDirectory/account-111122223333/modules/secrets/README.md)

### Networking Documentation and Runbooks
- [`modules/source/aws/aws-networking/account-111122223333/README.md`](modules/source/aws/aws-networking/account-111122223333/README.md)
- [`modules/source/aws/aws-networking/account-111122223333/docs/AWS-Network-Architecture.md`](modules/source/aws/aws-networking/account-111122223333/docs/AWS-Network-Architecture.md)
- [`modules/source/aws/aws-networking/account-111122223333/us-east-1/README.md`](modules/source/aws/aws-networking/account-111122223333/us-east-1/README.md)
- [`modules/source/aws/aws-networking/account-111122223333/us-east-2/README.md`](modules/source/aws/aws-networking/account-111122223333/us-east-2/README.md)
- [`modules/source/aws/aws-networking/account-111122223333/modules/vpc/README.md`](modules/source/aws/aws-networking/account-111122223333/modules/vpc/README.md)
- [`modules/source/aws/aws-networking/account-111122223333/modules/subnets/README.md`](modules/source/aws/aws-networking/account-111122223333/modules/subnets/README.md)
- [`modules/source/aws/aws-networking/account-111122223333/modules/transit-gateway/README.md`](modules/source/aws/aws-networking/account-111122223333/modules/transit-gateway/README.md)
- [`modules/source/aws/aws-networking/account-111122223333/modules/tgw-peering/README.md`](modules/source/aws/aws-networking/account-111122223333/modules/tgw-peering/README.md)
- [`modules/source/aws/aws-networking/account-111122223333/modules/network-firewall/README.md`](modules/source/aws/aws-networking/account-111122223333/modules/network-firewall/README.md)
- [`modules/source/aws/aws-networking/account-111122223333/modules/client-vpn/README.md`](modules/source/aws/aws-networking/account-111122223333/modules/client-vpn/README.md)

### Other Stack and Module Documentation
- [`modules/source/aws/aws-create-tf-backend/us-east-2/README.md`](modules/source/aws/aws-create-tf-backend/us-east-2/README.md)
- [`modules/source/aws/aws-secrets-manager/account-111122223333/us-east-2/README.md`](modules/source/aws/aws-secrets-manager/account-111122223333/us-east-2/README.md)
- [`modules/source/aws/aws-ssm/account-111122223333/README.md`](modules/source/aws/aws-ssm/account-111122223333/README.md)
- [`modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/README.md`](modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/README.md)
- [`modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/alb/README.md`](modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/alb/README.md)
- [`modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/ecr/README.md`](modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/ecr/README.md)
- [`modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/ecs/README.md`](modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/ecs/README.md)
- [`modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/iam/README.md`](modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/iam/README.md)
- [`modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/rds/README.md`](modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/rds/README.md)
- [`modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/secrets/README.md`](modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/secrets/README.md)
- [`modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/security-groups/README.md`](modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/security-groups/README.md)
- [`modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/waf/README.md`](modules/source/aws/aws-vaultwarden/account-111122223333/us-east-2/modules/waf/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/ad-connector/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/ad-connector/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/ad-replica/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/ad-replica/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/entraid-connector/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/entraid-connector/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/entraid-sync/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/entraid-sync/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/managed-ad/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/managed-ad/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/ssm-endpoints/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/ssm-endpoints/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/transit-gateway-peering/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/transit-gateway-peering/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/vpc-peering/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/vpc-peering/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/vpc-us-east-2/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/vpc-us-east-2/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/workspaces-directory/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/workspaces-directory/README.md)
- [`modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/workspaces/README.md`](modules/source/aws/aws-workspaces-vdi/account-111122223333/modules/workspaces/README.md)
- [`modules/source/aws/terraform-providers/account-111122223333/README.md`](modules/source/aws/terraform-providers/account-111122223333/README.md)
- [`modules/source/aws/terraform_backends/account-111122223333/README.md`](modules/source/aws/terraform_backends/account-111122223333/README.md)

## Notes
- This repository is maintained as a standalone deployment template.
- Validate environment-specific values in `config/deployment.env` before production rollout.
