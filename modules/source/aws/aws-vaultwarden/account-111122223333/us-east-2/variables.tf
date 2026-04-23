# ==============================================================================
# VARIABLES
# ==============================================================================

# ------------------------------------------------------------------------------
# GENERAL
# ------------------------------------------------------------------------------
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "account-111122223333"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "org-aws-vaultwarden"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "platform-team"
}

# ------------------------------------------------------------------------------
# NETWORKING - References to existing infrastructure
# ------------------------------------------------------------------------------
variable "vpc_name" {
  description = "Name of the existing VPC from networking project"
  type        = string
}

# ------------------------------------------------------------------------------
# VAULTWARDEN CONFIGURATION
# ------------------------------------------------------------------------------
variable "fqdn" {
  description = "Fully qualified domain name for VaultWarden"
  type        = string
}

variable "signups_allowed" {
  description = "Allow open user registration"
  type        = bool
  default     = false
}

variable "invitations_allowed" {
  description = "Allow user invitations"
  type        = bool
  default     = true
}

variable "show_password_hint" {
  description = "Show password hints on login page"
  type        = bool
  default     = false
}

variable "enable_websocket" {
  description = "Enable WebSocket for real-time sync"
  type        = bool
  default     = true
}

variable "enable_admin_panel" {
  description = "Enable the admin panel (/admin)"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "VaultWarden log level"
  type        = string
  default     = "info"
}

# ------------------------------------------------------------------------------
# PUSH NOTIFICATIONS (Optional)
# Requires registration at https://bitwarden.com/host/
# ------------------------------------------------------------------------------
variable "push_enabled" {
  description = "Enable mobile push notifications"
  type        = bool
  default     = false
}

variable "push_installation_id" {
  description = "Bitwarden push installation ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "push_installation_key" {
  description = "Bitwarden push installation key"
  type        = string
  default     = ""
  sensitive   = true
}

# ------------------------------------------------------------------------------
# SMTP CONFIGURATION (Optional)
# ------------------------------------------------------------------------------
variable "smtp_enabled" {
  description = "Enable SMTP for email notifications"
  type        = bool
  default     = false
}

variable "smtp_host" {
  description = "SMTP server hostname"
  type        = string
  default     = ""
}

variable "smtp_port" {
  description = "SMTP server port"
  type        = number
  default     = 587
}

variable "smtp_security" {
  description = "SMTP security (starttls, force_tls, off)"
  type        = string
  default     = "starttls"
}

variable "smtp_username" {
  description = "SMTP username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "smtp_password" {
  description = "SMTP password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "smtp_from" {
  description = "SMTP from address"
  type        = string
  default     = ""
}

variable "smtp_from_name" {
  description = "SMTP from display name"
  type        = string
  default     = "VaultWarden"
}

# ------------------------------------------------------------------------------
# ECS CONFIGURATION
# ------------------------------------------------------------------------------
variable "ecs_cpu" {
  description = "ECS task CPU units (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "ecs_memory" {
  description = "ECS task memory in MB"
  type        = number
  default     = 2048
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "container_image_tag" {
  description = "VaultWarden container image tag"
  type        = string
  default     = "testing" # Supports SSO
}

# ------------------------------------------------------------------------------
# RDS CONFIGURATION
# ------------------------------------------------------------------------------
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.medium"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_max_allocated_storage" {
  description = "RDS maximum allocated storage for autoscaling in GB"
  type        = number
  default     = 500
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "vaultwarden"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "vaultwarden"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 14
}

variable "db_deletion_protection" {
  description = "Enable deletion protection for RDS"
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when deleting RDS"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# WAF CONFIGURATION
# ------------------------------------------------------------------------------
variable "waf_rate_limit" {
  description = "WAF rate limit (requests per 5 minutes per IP)"
  type        = number
  default     = 2000
}

# ------------------------------------------------------------------------------
# CERTIFICATE CONFIGURATION
# ------------------------------------------------------------------------------
variable "use_imported_certificate" {
  description = "Use an imported certificate instead of ACM-issued"
  type        = bool
  default     = true
}

variable "imported_certificate_arn" {
  description = "ARN of imported ACM certificate (if use_imported_certificate is true)"
  type        = string
  default     = "" # Set after importing certificate
}

# ------------------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------------------
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}
