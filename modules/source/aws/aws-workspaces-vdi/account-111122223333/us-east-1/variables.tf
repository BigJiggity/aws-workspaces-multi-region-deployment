# ==============================================================================
# INPUT VARIABLES
# Project: Generic WorkSpaces VDI - US-East-1
#
# These variables configure the WorkSpaces deployment with:
#   - AD Connector pointing to self-managed AD in us-east-2
#   - WorkSpaces instances in us-east-1
#   - Cross-region authentication via TGW peering
# ==============================================================================

# ------------------------------------------------------------------------------
# REMOTE STATE CONFIGURATION – US-EAST-1 NETWORKING
# References the org-aws-networking/us-east-1 project
# ------------------------------------------------------------------------------
variable "networking_state_bucket" {
  description = "S3 bucket containing the networking Terraform state"
  type        = string
  default     = "org-terraform-state-account-111122223333-111122223333"
}

variable "networking_state_key" {
  description = "S3 key path for the networking Terraform state file"
  type        = string
  default     = "networking/us-east-1/terraform.tfstate"
}

variable "networking_state_region" {
  description = "AWS region where the networking state bucket is located"
  type        = string
  default     = "us-east-2"
}

# ------------------------------------------------------------------------------
# REMOTE STATE CONFIGURATION – US-EAST-2 PRIMARY DC NETWORKING
# References the org-aws-networking/us-east-2 project for DC VPC
# ------------------------------------------------------------------------------
variable "dc_networking_state_bucket" {
  description = "S3 bucket containing the DC networking Terraform state"
  type        = string
  default     = "org-terraform-state-account-111122223333-111122223333"
}

variable "dc_networking_state_key" {
  description = "S3 key path for the DC networking Terraform state file"
  type        = string
  default     = "networking/us-east-2/terraform.tfstate"
}

variable "dc_networking_state_region" {
  description = "AWS region where the DC networking state bucket is located"
  type        = string
  default     = "us-east-2"
}

# ------------------------------------------------------------------------------
# REMOTE STATE CONFIGURATION – SELF-MANAGED AD (account-111122223333)
# References the self-managed AD domain controllers
# ------------------------------------------------------------------------------
variable "ad_account_000000000000_state_bucket" {
  description = "S3 bucket containing the AD account-111122223333 Terraform state"
  type        = string
  default     = "org-terraform-state-account-111122223333-111122223333"
}

variable "ad_account_000000000000_state_key" {
  description = "S3 key path for the AD account-111122223333 Terraform state file"
  type        = string
  default     = "account-111122223333/terraform.tfstate"
}

variable "ad_account_000000000000_state_region" {
  description = "AWS region where the AD account-111122223333 state bucket is located"
  type        = string
  default     = "us-east-2"
}

# ------------------------------------------------------------------------------
# LOCAL VPC CONFIGURATION
# Fallback values if remote state unavailable
# ------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block of the local VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "tgw_id" {
  description = "Transit Gateway ID (fallback if remote state unavailable)"
  type        = string
  default     = ""
}

variable "tgw_route_table_id" {
  description = "Transit Gateway route table ID (fallback)"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# ACTIVE DIRECTORY CONFIGURATION
# Self-managed AD domain (from account-111122223333)
# ------------------------------------------------------------------------------
variable "ad_domain_name" {
  description = "Fully qualified domain name for the self-managed AD domain"
  type        = string
  default     = "example.internal"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.ad_domain_name))
    error_message = "ad_domain_name must be a valid fully qualified domain name."
  }
}

variable "ad_netbios_name" {
  description = "NetBIOS name for the AD domain (max 15 characters, uppercase)"
  type        = string
  default     = "ORG"

  validation {
    condition     = length(var.ad_netbios_name) <= 15 && can(regex("^[A-Z][A-Z0-9-]*$", var.ad_netbios_name))
    error_message = "ad_netbios_name must be 15 characters or less, uppercase letters/numbers/hyphens only."
  }
}

# ------------------------------------------------------------------------------
# AD CONNECTOR CONFIGURATION
# Credentials are now pulled from AWS Secrets Manager (see secrets.tf)
# ------------------------------------------------------------------------------
variable "ad_connector_service_account" {
  description = "Service account username in AD with permissions to join computers to domain"
  type        = string
  default     = "svc_adconnector"
}

# ------------------------------------------------------------------------------
# WORKSPACES CONFIGURATION
# AWS WorkSpaces virtual desktop settings
# ------------------------------------------------------------------------------
variable "workspaces_bundle_id" {
  description = "WorkSpaces bundle ID. Get from: aws workspaces describe-workspace-bundles --region us-east-1"
  type        = string
  default     = ""
}

variable "workspaces_running_mode" {
  description = "WorkSpaces running mode: AUTO_STOP (pay-per-hour) or ALWAYS_ON (monthly flat rate)"
  type        = string
  default     = "AUTO_STOP"

  validation {
    condition     = contains(["AUTO_STOP", "ALWAYS_ON"], var.workspaces_running_mode)
    error_message = "workspaces_running_mode must be 'AUTO_STOP' (hourly billing) or 'ALWAYS_ON' (monthly billing)."
  }
}

variable "workspaces_auto_stop_timeout" {
  description = "Minutes of inactivity before AUTO_STOP WorkSpaces disconnect (60-43200 minutes)"
  type        = number
  default     = 60

  validation {
    condition     = var.workspaces_auto_stop_timeout >= 60 && var.workspaces_auto_stop_timeout <= 43200
    error_message = "workspaces_auto_stop_timeout must be between 60 (1 hour) and 43200 (30 days) minutes."
  }
}

variable "workspaces_compute_type" {
  description = "Compute type for WorkSpaces"
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["VALUE", "STANDARD", "PERFORMANCE", "POWER", "POWERPRO", "GRAPHICS", "GRAPHICSPRO"], var.workspaces_compute_type)
    error_message = "workspaces_compute_type must be one of: VALUE, STANDARD, PERFORMANCE, POWER, POWERPRO, GRAPHICS, GRAPHICSPRO."
  }
}

variable "workspaces_root_volume_size" {
  description = "Root volume (C: drive) size in GB for WorkSpaces (options: 80, 175, or 350 GB)"
  type        = number
  default     = 80

  validation {
    condition     = contains([80, 175, 350], var.workspaces_root_volume_size)
    error_message = "workspaces_root_volume_size must be 80, 175, or 350 GB."
  }
}

variable "workspaces_user_volume_size" {
  description = "User volume (D: drive) size in GB for WorkSpaces (options: 10, 50, or 100 GB)"
  type        = number
  default     = 50

  validation {
    condition     = contains([10, 50, 100], var.workspaces_user_volume_size)
    error_message = "workspaces_user_volume_size must be 10, 50, or 100 GB."
  }
}

variable "workspaces_users" {
  description = "List of AD usernames to provision WorkSpaces for (users must exist in AD)"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for user in var.workspaces_users : can(regex("^[a-zA-Z0-9._-]+$", user))])
    error_message = "workspaces_users must contain valid AD usernames (alphanumeric, dots, underscores, hyphens only)."
  }
}

# ------------------------------------------------------------------------------
# TAGGING
# Additional tags to apply to all resources
# ------------------------------------------------------------------------------
variable "tags" {
  description = "Additional tags to apply to all resources (merged with default tags in main.tf)"
  type        = map(string)
  default     = {}
}
