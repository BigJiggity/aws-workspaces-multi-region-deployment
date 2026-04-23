# ==============================================================================
# INPUT VARIABLES - WorkSpaces Instances
# ==============================================================================

variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "directory_id" {
  description = "WorkSpaces directory ID"
  type        = string
}

variable "workspaces" {
  description = "WorkSpaces definitions"
  type = list(object({
    name_suffix = string
    user_name   = string
    bundle_id   = string
  }))
}

variable "running_mode" {
  description = "WorkSpaces running mode"
  type        = string
}

variable "auto_stop_timeout" {
  description = "Auto-stop timeout in minutes"
  type        = number
}

variable "root_volume_size" {
  description = "Root volume size override"
  type        = number
  default     = null
}

variable "user_volume_size" {
  description = "User volume size override"
  type        = number
  default     = null
}

variable "compute_type" {
  description = "Compute type override"
  type        = string
  default     = null
}

variable "tags" {
  description = "Standard tags"
  type        = map(string)
}

variable "create_timeout" {
  description = "Create timeout for WorkSpaces (e.g., 90m)"
  type        = string
  default     = "90m"
}
