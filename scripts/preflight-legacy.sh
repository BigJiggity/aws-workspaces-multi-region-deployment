#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Tooling and credential checks
# -----------------------------------------------------------------------------
echo "Preflight: checking required tooling..."
command -v terraform >/dev/null || { echo "ERROR: terraform not found in PATH"; exit 1; }
command -v terragrunt >/dev/null || { echo "ERROR: terragrunt not found in PATH"; exit 1; }
command -v aws >/dev/null || { echo "ERROR: aws CLI not found in PATH"; exit 1; }

echo "Preflight: checking versions..."
terraform version
terragrunt --version
aws --version

echo "Preflight: verifying AWS credentials..."
aws sts get-caller-identity >/dev/null

# -----------------------------------------------------------------------------
# Backend checks (S3 + DynamoDB + KMS)
# -----------------------------------------------------------------------------
echo "Preflight: validating backend resources..."
BACKEND_BUCKET="workspaces-platform-terraform-state"
LOCK_TABLE="workspaces-platform-pilot-terraform-locks"
KMS_ALIAS="alias/workspaces-platform-pilot-terraform-state-01"
REGION="us-east-1"

aws s3api head-bucket --bucket "$BACKEND_BUCKET" --region "$REGION" >/dev/null
aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" >/dev/null
aws kms describe-key --key-id "$KMS_ALIAS" --region "$REGION" >/dev/null

echo "Preflight: OK"
