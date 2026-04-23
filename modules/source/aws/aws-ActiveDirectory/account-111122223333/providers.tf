# ==============================================================================
# PROVIDER CONFIGURATION
# Project: account-111122223333
# Multi-Region: us-east-2 (primary DC01), us-east-1 (DC02), ap-southeast-1 (DC03)
# ==============================================================================

# ------------------------------------------------------------------------------
# DEFAULT PROVIDER – US-EAST-2 (PRIMARY)
# Used for primary domain controller (DC01) and Route53
# ------------------------------------------------------------------------------
provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Project     = "account-111122223333"
      Environment = "account-111122223333"
      ManagedBy   = "terraform"
    }
  }
}

# ------------------------------------------------------------------------------
# VIRGINIA PROVIDER – US-EAST-1 (DC02)
# Used for secondary domain controller in WorkSpaces region
# ------------------------------------------------------------------------------
provider "aws" {
  alias  = "virginia"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "account-111122223333"
      Environment = "account-111122223333"
      ManagedBy   = "terraform"
    }
  }
}

# ------------------------------------------------------------------------------
# SINGAPORE PROVIDER – AP-SOUTHEAST-1 (DC03 REPLICA)
# Used for replica domain controller
# ------------------------------------------------------------------------------
provider "aws" {
  alias  = "singapore"
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project     = "account-111122223333"
      Environment = "account-111122223333"
      ManagedBy   = "terraform"
    }
  }
}
