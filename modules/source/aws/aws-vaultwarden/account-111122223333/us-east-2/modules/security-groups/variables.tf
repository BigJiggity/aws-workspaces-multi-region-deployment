# ==============================================================================
# SECURITY GROUPS MODULE - VARIABLES
# ==============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
