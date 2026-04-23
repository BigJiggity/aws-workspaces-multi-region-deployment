# ==============================================================================
# INPUT VARIABLES - Backend Infrastructure
# ==============================================================================

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for all named resources"
  type        = string
  default     = "workspaces-platform-pilot"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "workspaces-platform-terraform-state"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid S3 bucket name (lowercase, 3-63 chars)."
  }
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "workspaces-platform-pilot-terraform-locks"
}

variable "kms_alias" {
  description = "KMS alias used for Terraform state encryption key"
  type        = string
  default     = "alias/workspaces-platform-pilot-terraform-state-01"
}

variable "state_key_prefix" {
  description = "Prefix path used in backend state keys"
  type        = string
  default     = "workspaces/platform/us-east-1"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "workspaces-platform-pilot"
    Environment = "Pilot"
    ManagedBy   = "terraform"
    Owner       = "workspaces-platform-it"
    Department  = "WORKSPACES-PLATFORM"
    Application = "terraform-backend"
    CostCenter  = "WorkspacesPilot"
    Region      = "us-east-1"
    DataClass   = "Internal"
    Criticality = "Medium"
    Compliance  = "Internal"
  }
}
