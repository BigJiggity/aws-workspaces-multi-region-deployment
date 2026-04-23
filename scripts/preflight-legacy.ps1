$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Tooling and credential checks
# -----------------------------------------------------------------------------
Write-Host "Preflight: checking required tooling..."
Get-Command terraform | Out-Null
Get-Command terragrunt | Out-Null
Get-Command aws | Out-Null

Write-Host "Preflight: checking versions..."
terraform version
terragrunt --version
aws --version

Write-Host "Preflight: verifying AWS credentials..."
aws sts get-caller-identity | Out-Null

# -----------------------------------------------------------------------------
# Backend checks (S3 + DynamoDB + KMS)
# -----------------------------------------------------------------------------
Write-Host "Preflight: validating backend resources..."
$BackendBucket = "workspaces-platform-terraform-state"
$LockTable = "workspaces-platform-pilot-terraform-locks"
$KmsAlias = "alias/workspaces-platform-pilot-terraform-state-01"
$Region = "us-east-1"

aws s3api head-bucket --bucket $BackendBucket --region $Region | Out-Null
aws dynamodb describe-table --table-name $LockTable --region $Region | Out-Null
aws kms describe-key --key-id $KmsAlias --region $Region | Out-Null

Write-Host "Preflight: OK"
