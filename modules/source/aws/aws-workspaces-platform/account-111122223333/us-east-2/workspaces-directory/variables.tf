# ==============================================================================
# INPUT VARIABLES - WorkSpaces Directory Registration
# ==============================================================================

variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "directory_id" {
  description = "Directory ID (AD Connector or Managed AD)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for WorkSpaces"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR for security group rules"
  type        = string
}

variable "directory_subnet_ids" {
  description = "Subnets for WorkSpaces directory registration"
  type        = list(string)
}

variable "subnet_ids" {
  description = "Subnets for WorkSpaces"
  type        = list(string)
}

variable "trusted_cidrs" {
  description = "Trusted CIDRs for directory security group"
  type = list(object({
    source      = string
    description = string
  }))
}

variable "tags" {
  description = "Standard tags"
  type        = map(string)
}
