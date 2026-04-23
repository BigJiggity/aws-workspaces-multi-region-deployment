# ==============================================================================
# MODULE OUTPUTS: AD-REPLICA
# ==============================================================================

output "replica_region" {
  description = "Region where the AD replica is deployed"
  value       = data.aws_region.current.id
}

output "replica_dns_ips" {
  description = "DNS IP addresses of replica domain controllers"
  value       = data.aws_directory_service_directory.replica.dns_ip_addresses
}

output "security_group_id" {
  description = "Security group ID for AD replica"
  value       = aws_security_group.ad_replica.id
}

output "directory_id" {
  description = "Directory ID (same as primary)"
  value       = var.directory_id
}
