# ==============================================================================
# TERRAFORM BACKEND CONFIGURATION
# Project: account-111122223333
# Self-Managed Active Directory Domain Controllers
# ==============================================================================

terraform {
  backend "s3" {
    bucket         = "org-terraform-state-account-111122223333-111122223333"
    key            = "account-111122223333/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "org-terraform-state-account-111122223333"
  }
}
