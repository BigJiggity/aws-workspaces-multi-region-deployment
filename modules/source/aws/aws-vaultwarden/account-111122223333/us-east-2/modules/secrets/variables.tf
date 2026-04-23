# ==============================================================================
# SECRETS MODULE - VARIABLES
# ==============================================================================

variable "name_prefix" {
  description = "Prefix for secret names"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "admin_token_enabled" {
  description = "Whether to create admin token secret"
  type        = bool
  default     = true
}

variable "push_installation_id" {
  description = "Bitwarden push installation ID"
  type        = string
  default     = ""
}

variable "push_installation_key" {
  description = "Bitwarden push installation key"
  type        = string
  default     = ""
}

variable "smtp_username" {
  description = "SMTP username"
  type        = string
  default     = ""
}

variable "smtp_password" {
  description = "SMTP password"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
