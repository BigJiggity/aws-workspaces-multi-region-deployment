# ==============================================================================
# PROVIDER CONFIGURATION
# Project: Generic SSM VPC Endpoints - US-East-2
# ==============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "org-ssm-endpoints-us-east-2"
      ManagedBy   = "terraform"
      Environment = "account-111122223333"
    }
  }
}
