# ==============================================================================
# TERRAFORM & PROVIDER VERSION CONSTRAINTS
# Project: Generic WorkSpaces VDI - US-East-1
#
# This project deploys AWS WorkSpaces with:
#   - AD Connector pointing to self-managed AD (DC01, DC02 in us-east-2)
#   - WorkSpaces instances in us-east-1
#   - Cross-region authentication via TGW peering
# ==============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }

    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}
