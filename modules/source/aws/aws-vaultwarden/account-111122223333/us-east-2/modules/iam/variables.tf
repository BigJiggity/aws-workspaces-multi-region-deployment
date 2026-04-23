# ==============================================================================
# IAM MODULE - VARIABLES
# ==============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  type        = string
}

variable "secrets_arns" {
  description = "List of Secrets Manager secret ARNs"
  type        = list(string)
}

variable "cloudwatch_log_group_arns" {
  description = "List of CloudWatch log group ARNs"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
