# ==============================================================================
# TERRAFORM AND PROVIDER CONFIGURATION
# ==============================================================================

terraform {
  # Enforce modern Terraform version for security and features
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70" # Stable v5 series
    }
  }
}

# AWS Provider - automatically uses credentials from:
#   - ~/.aws/credentials (default profile)
#   - Environment variables (AWS_ACCESS_KEY_ID, etc.)
#   - EC2/ECS instance role if running on AWS
provider "aws" {
  region = var.region
}