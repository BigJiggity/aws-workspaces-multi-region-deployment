# ==============================================================================
# REMOTE BACKEND CONFIGURATION
# Project: Generic WorkSpaces VDI - US-East-1
#
# Terraform state is stored in a centralized S3 bucket with:
#   - Server-side encryption (SSE-S3)
#   - Versioning enabled for state history
#   - DynamoDB table for state locking
# ==============================================================================

terraform {
  backend "s3" {
    bucket         = "org-terraform-state-account-111122223333-111122223333"
    key            = "workspaces/org-workspaces-vdi-us-east-1/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "org-terraform-state-account-111122223333"
    encrypt        = true
  }
}
