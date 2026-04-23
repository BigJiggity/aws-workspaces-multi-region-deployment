# ==============================================================================
# INPUT VARIABLES – Configurable Parameters
# Project: Generic SSM VPC Endpoints - US-East-2
# ==============================================================================

# ------------------------------------------------------------------------------
# REGION CONFIGURATION
# ------------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "name_prefix" {
  description = "Prefix for resource names (e.g., 'org-use2' for us-east-2)"
  type        = string
  default     = "org-use2"
}

# ------------------------------------------------------------------------------
# REMOTE STATE CONFIGURATION
# References the org-vpc_firewall_us-east-2-account-111122223333 project
# ------------------------------------------------------------------------------
variable "vpc_firewall_state_bucket" {
  description = "S3 bucket containing VPC Firewall Terraform state"
  type        = string
  default     = "org-terraform-state-account-111122223333-111122223333"
}

variable "vpc_firewall_state_key" {
  description = "S3 key for VPC Firewall Terraform state file"
  type        = string
  default     = "us-east-2/account-111122223333/terraform.tfstate"
}

variable "vpc_firewall_state_region" {
  description = "AWS region where VPC Firewall state bucket is located"
  type        = string
  default     = "us-east-2"
}

# ------------------------------------------------------------------------------
# TAGGING
# ------------------------------------------------------------------------------
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
