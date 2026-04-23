# ==============================================================================
# REMOTE BACKEND CONFIGURATION
# ONLY UNCOMMENT AFTER FIRST `terraform apply`
# This file's own state will then be migrated to the remote backend
# ==============================================================================

terraform {
  backend "s3" {
    bucket         = "org-terraform-state-account-111122223333-111122223333"
    key            = "backend-setup/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "org-terraform-state-account-111122223333"
    encrypt        = true
  }
}