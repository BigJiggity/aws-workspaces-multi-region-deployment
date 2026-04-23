# ==============================================================================
# MODULE OUTPUTS: MANAGED-AD
# ==============================================================================

output "directory_id" {
  description = "ID of the Managed AD directory"
  value       = aws_directory_service_directory.this.id
}

output "directory_name" {
  description = "Fully qualified domain name"
  value       = aws_directory_service_directory.this.name
}

output "dns_ip_addresses" {
  description = "DNS IP addresses of domain controllers"
  value       = aws_directory_service_directory.this.dns_ip_addresses
}

output "security_group_id" {
  description = "Security group ID for Managed AD"
  value       = aws_security_group.managed_ad.id
}

output "admin_password_secret_arn" {
  description = "Secrets Manager ARN for admin password"
  value       = aws_secretsmanager_secret.ad_admin.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.ad_logs.name
}

output "edition" {
  description = "Directory edition"
  value       = aws_directory_service_directory.this.edition
}

output "access_url" {
  description = "Access URL for the directory"
  value       = aws_directory_service_directory.this.access_url
}
