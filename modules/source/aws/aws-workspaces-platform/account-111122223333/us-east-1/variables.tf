# ==============================================================================
# INPUT VARIABLES - WorkSpaces Pilot
# ==============================================================================

variable "deployment_layer" {
  description = "Deployment layer (e.g., live)"
  type        = string
}

variable "cloud_provider" {
  description = "Cloud provider name"
  type        = string
}

variable "stack_name" {
  description = "Stack name for naming and tagging"
  type        = string
}

variable "account_scope" {
  description = "Account scope label"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "unit_path" {
  description = "Terragrunt unit path for traceability"
  type        = string
}

variable "source_path" {
  description = "Source module path for traceability"
  type        = string
}

variable "name_prefix" {
  description = "Naming prefix for all resources"
  type        = string
  default     = "workspaces-platform-pilot"
}

variable "directory_id" {
  description = "Directory ID (AD Connector or Managed AD) already available"
  type        = string
}

variable "directory_name" {
  description = "Directory name (e.g., WORKSPACES-PLATFORM.LOCAL)"
  type        = string
}

variable "workspaces_subnets" {
  description = "Map of CIDR -> {az, az_id} for WorkSpaces subnets"
  type = map(object({
    az    = string
    az_id = string
  }))
}

variable "workspaces" {
  description = "WorkSpaces to create (user + bundle mapping)"
  type = list(object({
    name_suffix = string
    user_name   = string
    bundle_id   = string
  }))
}

variable "trusted_cidrs" {
  description = "Trusted CIDRs for directory security group"
  type = list(object({
    source      = string
    description = string
  }))
}

variable "tags" {
  description = "Standard resource tags"
  type        = map(string)
}

variable "workspaces_running_mode" {
  description = "Running mode: AUTO_STOP or ALWAYS_ON"
  type        = string
  default     = "AUTO_STOP"
}

variable "workspaces_auto_stop_timeout" {
  description = "Auto-stop timeout in minutes for AUTO_STOP"
  type        = number
  default     = 60
}

variable "workspaces_root_volume_size" {
  description = "Root volume size in GB (optional override)"
  type        = number
  default     = null
}

variable "workspaces_user_volume_size" {
  description = "User volume size in GB (optional override)"
  type        = number
  default     = null
}

variable "workspaces_compute_type" {
  description = "Compute type name (optional override)"
  type        = string
  default     = null
}

variable "workspaces_create_timeout" {
  description = "Create timeout for WorkSpaces (e.g., 90m)"
  type        = string
  default     = "90m"
}
