# ==============================================================================
# TERRAFORM BACKEND CONFIGURATION
# Project: Generic SSM VPC Endpoints - US-East-2
#
# State is stored in S3 with DynamoDB locking for consistency.
# ==============================================================================

terraform {
  backend "s3" {
    bucket         = "org-terraform-state-account-111122223333-111122223333"
    key            = "org-ssm-endpoints-us-east-2/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "org-terraform-state-account-111122223333"
    encrypt        = true
  }
}
