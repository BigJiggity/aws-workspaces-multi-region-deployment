# AWS WorkSpaces Multi-Region Deployment (Terragrunt + Terraform)

## What This Project Delivers
- Terragrunt repository layout aligned to best practices (`root.hcl`, `live/`, `modules/source/`).
- Multi-region deployment scaffold with account/region pathing under `live/aws/...`.
- Download-safe sanitized placeholders (no provider binaries, state files, or local cache artifacts).
- Centralized bootstrap script to configure account IDs, regions, naming, backend, and WorkSpaces parameters.
- Documentation aligned with AWS Well-Architected pillars.

## Quickstart
1. Copy the config template:

```bash
cp config/deployment.env.example config/deployment.env
```

2. Edit `config/deployment.env` for your organization.

3. Apply configuration to the repository:

```bash
./scripts/configure-project.sh --config config/deployment.env
```

4. Run preflight checks:

```bash
./scripts/preflight.sh --config config/deployment.env
```

5. Deploy backend first (recommended):

```bash
cd backend/<PRIMARY_REGION>
terraform init
terraform apply
```

6. Deploy selected Terragrunt units from `live/aws/...`.

## Repository Layout
- `root.hcl`: global Terragrunt defaults.
- `live/`: deployable Terragrunt units and hierarchy metadata.
- `modules/source/aws/`: Terraform implementations.
- `backend/`: Terraform backend bootstrap (S3 + DynamoDB + KMS).
- `scripts/`: configuration, preflight, and workflow automation scripts.
- `docs/`: architecture, standards, and Well-Architected documentation.

## Primary Configuration Script
- `scripts/configure-project.sh`

This script updates:
- account ID and account-scoped paths (`account-<id>`)
- selected regions for the WorkSpaces platform stack
- global naming/tag metadata
- backend naming defaults (bucket/table/KMS alias)
- WorkSpaces pool values (VPC, subnets, SAML secret ARN)

## Notes
- This repository is maintained as a standalone deployment template.
- Validate environment-specific values in `config/deployment.env` before production rollout.
