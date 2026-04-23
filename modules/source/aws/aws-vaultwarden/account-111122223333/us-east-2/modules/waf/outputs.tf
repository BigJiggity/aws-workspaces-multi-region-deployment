# ==============================================================================
# WAF MODULE - OUTPUTS
# ==============================================================================

output "web_acl_arn" {
  description = "ARN of the WAF WebACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_id" {
  description = "ID of the WAF WebACL"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_name" {
  description = "Name of the WAF WebACL"
  value       = aws_wafv2_web_acl.main.name
}

output "log_group_name" {
  description = "CloudWatch log group name for WAF logs"
  value       = aws_cloudwatch_log_group.waf.name
}
