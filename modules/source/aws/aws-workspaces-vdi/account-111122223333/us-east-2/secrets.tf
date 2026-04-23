# ==============================================================================
# SECRETS DATA SOURCE
# Retrieves credentials from AWS Secrets Manager
#
# All infrastructure credentials are stored centrally in:
#   Secret Name: org-infrastructure/credentials
#   Region: us-east-2
#
# This eliminates the need for TF_VAR_* environment variables for passwords.
# ==============================================================================

# ------------------------------------------------------------------------------
# DATA SOURCE: AWS SECRETS MANAGER
# ------------------------------------------------------------------------------
data "aws_secretsmanager_secret" "credentials" {
  name = "org-infrastructure/credentials"
}

data "aws_secretsmanager_secret_version" "credentials" {
  secret_id = data.aws_secretsmanager_secret.credentials.id
}

locals {
  # Parse the JSON secret string
  credentials = jsondecode(data.aws_secretsmanager_secret_version.credentials.secret_string)

  # Extract individual credentials
  ad_admin_password        = local.credentials.ad_admin_password
  ad_safe_mode_password    = local.credentials.ad_safe_mode_password
  svc_workspaces_password  = local.credentials.svc_workspaces_password
  svc_adconnector_password = local.credentials.svc_adconnector_password
}
