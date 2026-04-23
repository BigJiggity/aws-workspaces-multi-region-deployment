# ==============================================================================
# INPUT VARIABLES - WorkSpaces Pool (SOC)
# ==============================================================================

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for WorkSpaces pooled module networking resources"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for WorkSpaces pooled module resources"
  type        = list(string)
}

variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "pool_name" {
  description = "Unique WorkSpaces pool name"
  type        = string
}

variable "pool_description" {
  description = "Description for the WorkSpaces pool"
  type        = string
  default     = "SOC WorkSpaces Pool"
}

variable "pool_directory_id" {
  description = "WorkSpaces Pools directory ID (must match pattern wsd-xxxxxxxx)"
  type        = string
}

variable "saml_xml_secret_arn" {
  description = "Secrets Manager ARN containing SAML metadata XML for pooled directory auth"
  type        = string
}

variable "bundle_id" {
  description = "WorkSpaces bundle ID to use for this pool"
  type        = string
}

variable "running_mode" {
  description = "Pool running mode"
  type        = string
  default     = "AUTO_STOP"

  validation {
    condition     = contains(["AUTO_STOP", "ALWAYS_ON"], var.running_mode)
    error_message = "running_mode must be AUTO_STOP or ALWAYS_ON."
  }
}

variable "desired_user_sessions" {
  description = "Initial desired user sessions for the pool"
  type        = number
  default     = 2
}

variable "min_user_sessions" {
  description = "Minimum user sessions for auto scaling target"
  type        = number
  default     = 2
}

variable "max_user_sessions" {
  description = "Maximum user sessions for auto scaling target"
  type        = number
  default     = 10
}

variable "max_user_duration_minutes" {
  description = "Maximum session duration in minutes"
  type        = number
  default     = 480
}

variable "disconnect_timeout_minutes" {
  description = "Disconnect timeout in minutes"
  type        = number
  default     = 60
}

variable "idle_disconnect_timeout_minutes" {
  description = "Idle disconnect timeout in minutes"
  type        = number
  default     = 30
}

variable "application_settings_status" {
  description = "Enable or disable persistent application settings"
  type        = string
  default     = "ENABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.application_settings_status)
    error_message = "application_settings_status must be ENABLED or DISABLED."
  }
}

variable "application_settings_group" {
  description = "Settings group prefix for persistent application settings"
  type        = string
  default     = "workspaces-platform-pilot/soc-pool"
}

variable "tags" {
  description = "Standard tags"
  type        = map(string)
}
