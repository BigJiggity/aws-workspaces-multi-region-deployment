# Global metadata shared by all deployment units.
# Updated by scripts/configure-project.sh.

locals {
  deployment_layer = "live"

  name_prefix = "example-workspaces-platform-dev"
  region      = "us-east-1"

  tags = {
    Project     = "example-workspaces-platform"
    Environment = "dev"
    ManagedBy   = "terragrunt"
    Owner       = "platform-team"
    Department  = "PLATFORM"
    Application = "aws-workspaces-multi-region-deployment"
    CostCenter  = "shared-platform"
    Region      = "us-east-1"
    DataClass   = "Internal"
    Criticality = "Medium"
    Compliance  = "Internal"
  }
}
