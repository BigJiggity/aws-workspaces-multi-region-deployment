# ==============================================================================
# ALB MODULE - OUTPUTS
# ==============================================================================

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_id" {
  description = "ID of the ALB"
  value       = aws_lb.main.id
}

output "dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "zone_id" {
  description = "Route53 zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

output "arn_suffix" {
  description = "ARN suffix for CloudWatch metrics"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group"
  value       = aws_lb_target_group.main.arn_suffix
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}
