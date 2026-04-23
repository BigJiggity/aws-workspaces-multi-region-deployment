# ==============================================================================
# INPUT VARIABLES
# Project: account-111122223333
# Self-Managed Active Directory Domain Controllers
# ==============================================================================

# ------------------------------------------------------------------------------
# REMOTE STATE CONFIGURATION – US-EAST-2 VPC/FIREWALL (DC01)
# ------------------------------------------------------------------------------
variable "vpc_firewall_state_bucket" {
  description = "S3 bucket containing the VPC/Firewall Terraform state (us-east-2)"
  type        = string
  default     = "org-terraform-state-account-111122223333-111122223333"
}

variable "vpc_firewall_state_key" {
  description = "S3 key path for the VPC/Firewall Terraform state file"
  type        = string
  default     = "us-east-2/account-111122223333/terraform.tfstate"
}

variable "vpc_firewall_state_region" {
  description = "AWS region where the VPC/Firewall state bucket is located"
  type        = string
  default     = "us-east-2"
}

# ------------------------------------------------------------------------------
# REMOTE STATE CONFIGURATION – US-EAST-1 NETWORKING (DC02)
# ------------------------------------------------------------------------------
variable "use1_networking_state_bucket" {
  description = "S3 bucket containing the us-east-1 networking Terraform state"
  type        = string
  default     = "org-terraform-state-account-111122223333-111122223333"
}

variable "use1_networking_state_key" {
  description = "S3 key path for the us-east-1 networking Terraform state file"
  type        = string
  default     = "networking/us-east-1/terraform.tfstate"
}

variable "use1_networking_state_region" {
  description = "AWS region where the us-east-1 networking state bucket is located"
  type        = string
  default     = "us-east-2"
}

# Fallback values for us-east-1
variable "use1_vpc_cidr" {
  description = "CIDR block of the us-east-1 VPC"
  type        = string
  default     = "10.1.0.0/16"
}

# ------------------------------------------------------------------------------
# REMOTE STATE CONFIGURATION – AP-SOUTHEAST-1 LANDING ZONE (DC03)
# ------------------------------------------------------------------------------
variable "landing_zone_state_bucket" {
  description = "S3 bucket containing the landing zone Terraform state (ap-southeast-1)"
  type        = string
  default     = "org-terraform-state-account-111122223333-111122223333-ap-southeast-1"
}

variable "landing_zone_state_key" {
  description = "S3 key path for the landing zone Terraform state file"
  type        = string
  default     = "env:/vpc_tgw_fw_ohio/backend-setup/terraform.tfstate"
}

variable "landing_zone_state_region" {
  description = "AWS region where the landing zone state bucket is located"
  type        = string
  default     = "ap-southeast-1"
}

# Fallback values for landing zone
variable "landing_zone_vpc_cidr" {
  description = "CIDR block of the landing zone VPC"
  type        = string
  default     = "10.2.0.0/16"
}

# ------------------------------------------------------------------------------
# ACTIVE DIRECTORY CONFIGURATION
# ------------------------------------------------------------------------------
variable "ad_domain_name" {
  description = "Fully qualified domain name for the AD domain"
  type        = string
  default     = "example.internal"
}

variable "ad_netbios_name" {
  description = "NetBIOS name for the AD domain (max 15 characters)"
  type        = string
  default     = "ORG"
}

variable "ad_safe_mode_password" {
  description = "Directory Services Restore Mode (DSRM) password"
  type        = string
  sensitive   = true
}

variable "ad_admin_password" {
  description = "Password for the domain Administrator account"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# EC2 INSTANCE CONFIGURATION
# ------------------------------------------------------------------------------
variable "instance_type" {
  description = "EC2 instance type for domain controllers"
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "Name of existing EC2 key pair (leave empty to create new)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 100
}

# ------------------------------------------------------------------------------
# STATIC IP ADDRESSES FOR DOMAIN CONTROLLERS
# ------------------------------------------------------------------------------
variable "dc01_private_ip" {
  description = "Static private IP for DC01 (must be within us-east-2a management subnet)"
  type        = string
  default     = "10.0.12.10"
}

variable "dc02_private_ip" {
  description = "Static private IP for DC02 (must be within us-east-1a management subnet)"
  type        = string
  default     = "10.1.12.10"
}

variable "dc03_private_ip" {
  description = "Static private IP for DC03 (must be within ap-southeast-1a management subnet)"
  type        = string
  default     = "10.2.10.10"
}

# ------------------------------------------------------------------------------
# TAGGING
# ------------------------------------------------------------------------------
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
