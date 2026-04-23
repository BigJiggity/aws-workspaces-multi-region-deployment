# ==============================================================================
# AWS PROVIDER CONFIGURATION
# Project: Generic WorkSpaces VDI - US-East-2 Deployment
# Region: us-east-2 (Ohio)
#
# Single-region deployment:
#   - All resources deployed in us-east-2
#   - AD Connector points to DC01/DC02 (local DCs)
#   - WorkSpaces in private subnets
# ==============================================================================

# ------------------------------------------------------------------------------
# PRIMARY PROVIDER – US-EAST-2 (Ohio)
# Used for: AD Connector, WorkSpaces Directory, WorkSpaces instances
# VPC infrastructure is referenced from org-vpc_firewall_us-east-2-account-111122223333
# ------------------------------------------------------------------------------
provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Environment = "VDI"
      Project     = "org-workspaces-vdi-use2"
      Region      = "us-east-2"
      Owner       = "system architects"
      CostCenter  = "CloudArchitecture"
      Backup      = "daily"
      ManagedBy   = "terraform"
      Compliance  = "high"
      CreatedDate = "2025-12-08"
    }
  }
}
