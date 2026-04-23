# Terraform Backend (S3 + DynamoDB + KMS)

## Purpose
Creates the remote state backend for all Terragrunt units in this repo.

## Structure
- `us-east-1/` contains the Terraform code for the backend resources.

## Runbook
```bash
# From repo root:
./preflight.sh

cd backend/us-east-1
terraform init
terraform plan
terraform apply
```

## Outputs
- S3 bucket name
- DynamoDB table name
- KMS key ARN
- Example backend config block


## Prerequisites
See [PREREQUISITES.md](../PREREQUISITES.md) for setup steps on macOS, Windows, and Linux.
