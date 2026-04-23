# ==============================================================================
# ECS MODULE - VARIABLES
# ==============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "vaultwarden"
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
}

variable "cpu" {
  description = "CPU units for the task"
  type        = number
  default     = 1024
}

variable "memory" {
  description = "Memory (MB) for the task"
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Number of tasks to run"
  type        = number
  default     = 2
}

variable "execution_role_arn" {
  description = "ARN of the ECS execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "vaultwarden_config" {
  description = "VaultWarden configuration"
  type = object({
    domain              = string
    signups_allowed     = bool
    invitations_allowed = bool
    show_password_hint  = bool
    admin_panel_enabled = bool
    websocket_enabled   = bool
    push_enabled        = bool
    log_level           = string
    smtp_host           = string
    smtp_port           = number
    smtp_security       = string
    smtp_from           = string
  })
}

variable "secrets_config" {
  description = "Secrets Manager ARNs"
  type = object({
    db_password_arn   = string
    admin_token_arn   = string
    push_id_arn       = string
    push_key_arn      = string
    smtp_username_arn = string
    smtp_password_arn = string
  })
}

variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
