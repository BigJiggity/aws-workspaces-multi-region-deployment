# ==============================================================================
# MODULE: SECRETS
# Retrieves credentials from AWS Secrets Manager
#
# Usage:
#   module "secrets" {
#     source = "./modules/secrets"
#   }
#
#   # Then access:
#   module.secrets.ad_admin_password
#   module.secrets.svc_adconnector_password
# ==============================================================================

variable "secret_name" {
  description = "Name of the secret in AWS Secrets Manager"
  type        = string
  default     = "org-infrastructure/credentials"
}

variable "region" {
  description = "AWS region where the secret is stored"
  type        = string
  default     = "us-east-2"
}

# ------------------------------------------------------------------------------
# DATA SOURCE: AWS SECRETS MANAGER
# ------------------------------------------------------------------------------
data "aws_secretsmanager_secret" "credentials" {
  name = var.secret_name
}

data "aws_secretsmanager_secret_version" "credentials" {
  secret_id = data.aws_secretsmanager_secret.credentials.id
}

locals {
  credentials = jsondecode(data.aws_secretsmanager_secret_version.credentials.secret_string)
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------
output "ad_admin_password" {
  description = "AD Administrator password"
  value       = local.credentials.ad_admin_password
  sensitive   = true
}

output "ad_safe_mode_password" {
  description = "AD Safe Mode (DSRM) password"
  value       = local.credentials.ad_safe_mode_password
  sensitive   = true
}

output "svc_workspaces_password" {
  description = "svc_workspaces service account password"
  value       = local.credentials.svc_workspaces_password
  sensitive   = true
}

output "svc_adconnector_password" {
  description = "svc_adconnector service account password"
  value       = local.credentials.svc_adconnector_password
  sensitive   = true
}

output "all_credentials" {
  description = "All credentials as a map"
  value       = local.credentials
  sensitive   = true
}
