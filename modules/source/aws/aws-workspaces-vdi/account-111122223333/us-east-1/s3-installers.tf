# ==============================================================================
# S3 INSTALLERS BUCKET REFERENCE
# Project: org-workspaces-vdi - US-East-1
#
# References the existing S3 bucket created by ap-southeast-1 deployment
# The bucket org-workspace-vdi-installs is shared across all regions
# ==============================================================================

# ------------------------------------------------------------------------------
# LOCAL VALUES
# The bucket is managed by the ap-southeast-1 deployment
# We just reference it by name - no data source needed
# ------------------------------------------------------------------------------
locals {
  installers_bucket_name = "org-workspace-vdi-installs"
  installers_bucket_arn  = "arn:aws:s3:::org-workspace-vdi-installs"
}

# ------------------------------------------------------------------------------
# DATA SOURCE: EXISTING S3 CREDENTIALS SECRET
# Credentials are stored in us-east-2 by the ap-southeast-1 deployment
# ------------------------------------------------------------------------------
data "aws_secretsmanager_secret" "s3_credentials" {
  provider = aws.ohio
  name     = "org-workspaces-s3-sync-credentials"
}

data "aws_secretsmanager_secret_version" "s3_credentials" {
  provider  = aws.ohio
  secret_id = data.aws_secretsmanager_secret.s3_credentials.id
}

locals {
  s3_credentials = jsondecode(data.aws_secretsmanager_secret_version.s3_credentials.secret_string)
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------
output "installers_bucket_name" {
  description = "S3 bucket name for WorkSpaces installers"
  value       = local.installers_bucket_name
}

output "installers_bucket_arn" {
  description = "S3 bucket ARN for WorkSpaces installers"
  value       = local.installers_bucket_arn
}

output "s3_sync_credentials_secret_arn" {
  description = "Secrets Manager ARN for S3 sync credentials"
  value       = data.aws_secretsmanager_secret.s3_credentials.arn
}
