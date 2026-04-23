# ==============================================================================
# AWS PROVIDER CONFIGURATION
# Project: Generic WorkSpaces VDI - US-East-1
#
# Deployment regions:
#   - Primary (us-east-1): AD Connector, WorkSpaces Directory, WorkSpaces
#   - Secondary (us-east-2): For accessing secrets and AD remote state
# ==============================================================================

# ------------------------------------------------------------------------------
# PRIMARY PROVIDER – US-EAST-1 (N. Virginia)
# Used for: AD Connector, WorkSpaces Directory, WorkSpaces instances
# VPC infrastructure is referenced from org-aws-networking/us-east-1
# ------------------------------------------------------------------------------
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "VDI"
      Project     = "org-workspaces-vdi"
      Owner       = "system architects"
      CostCenter  = "CloudArchitecture"
      Backup      = "daily"
      ManagedBy   = "terraform"
      Compliance  = "high"
      CreatedDate = "2025-12-10"
      Region      = "us-east-1"
    }
  }
}

# ------------------------------------------------------------------------------
# SECONDARY PROVIDER – US-EAST-2 (Ohio)
# Used for: Accessing secrets stored in us-east-2, AD remote state
# ------------------------------------------------------------------------------
provider "aws" {
  alias  = "ohio"
  region = "us-east-2"

  default_tags {
    tags = {
      Environment = "VDI"
      Project     = "org-workspaces-vdi"
      Owner       = "system architects"
      CostCenter  = "CloudArchitecture"
      ManagedBy   = "terraform"
    }
  }
}
