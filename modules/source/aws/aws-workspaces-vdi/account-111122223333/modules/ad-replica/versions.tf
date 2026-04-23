# ==============================================================================
# TERRAFORM & PROVIDER REQUIREMENTS
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.40"
      configuration_aliases = [aws.primary, aws.replica]
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}
