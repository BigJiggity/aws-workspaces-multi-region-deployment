# ==============================================================================
# S3 BUCKET REFERENCE FOR WORKSPACES INSTALLERS - US-EAST-2
# Project: org-workspaces-vdi
# Region: us-east-2
#
# References the shared S3 bucket created by ap-southeast-1 deployment
# Bucket: org-workspace-vdi-installs
#
# NOTE: The S3 bucket and IAM user are created in the ap-southeast-1 deployment.
# This file only creates outputs for convenience.
# ==============================================================================

# ------------------------------------------------------------------------------
# DATA SOURCE: EXISTING S3 BUCKET
# Created by ap-southeast-1 deployment
# ------------------------------------------------------------------------------
data "aws_s3_bucket" "workspaces_installers" {
  bucket = "org-workspace-vdi-installs"
}

# ------------------------------------------------------------------------------
# DATA SOURCE: EXISTING SECRETS MANAGER SECRET
# Contains S3 sync credentials created by ap-southeast-1 deployment
# ------------------------------------------------------------------------------
data "aws_secretsmanager_secret" "workspaces_s3_credentials" {
  name = "org-workspaces-s3-sync-credentials"
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------
output "installers_bucket_name" {
  description = "S3 bucket name for WorkSpaces installers (shared)"
  value       = data.aws_s3_bucket.workspaces_installers.id
}

output "installers_bucket_arn" {
  description = "S3 bucket ARN for WorkSpaces installers (shared)"
  value       = data.aws_s3_bucket.workspaces_installers.arn
}

output "s3_sync_credentials_secret_arn" {
  description = "Secrets Manager ARN for S3 sync credentials (from ap-southeast-1)"
  value       = data.aws_secretsmanager_secret.workspaces_s3_credentials.arn
}
