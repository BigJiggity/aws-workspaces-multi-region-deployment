# ==============================================================================
# WAF MODULE - VARIABLES
# ==============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the ALB to associate with WAF"
  type        = string
}

variable "rate_limit" {
  description = "Rate limit (requests per 5 minutes per IP)"
  type        = number
  default     = 2000
}

variable "ip_allowlist" {
  description = "List of IP CIDR ranges to allowlist"
  type        = list(string)
  default     = []
}

variable "enable_common_ruleset" {
  description = "Enable AWS Managed Rules Common Rule Set"
  type        = bool
  default     = true
}

variable "enable_sqli_ruleset" {
  description = "Enable AWS Managed Rules SQL Injection Rule Set"
  type        = bool
  default     = true
}

variable "enable_known_bad_inputs" {
  description = "Enable AWS Managed Rules Known Bad Inputs Rule Set"
  type        = bool
  default     = true
}

variable "enable_ip_reputation" {
  description = "Enable AWS Managed Rules IP Reputation List"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
