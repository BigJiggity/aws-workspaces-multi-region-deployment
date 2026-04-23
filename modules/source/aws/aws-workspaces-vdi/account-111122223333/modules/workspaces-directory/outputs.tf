# ==============================================================================
# MODULE OUTPUTS: WORKSPACES-DIRECTORY
# ==============================================================================

output "directory_id" {
  description = "WorkSpaces directory ID"
  value       = aws_workspaces_directory.this.id
}

output "registration_code" {
  description = "Registration code for WorkSpaces client"
  value       = aws_workspaces_directory.this.registration_code
  sensitive   = true
}

output "dns_ip_addresses" {
  description = "DNS IP addresses"
  value       = aws_workspaces_directory.this.dns_ip_addresses
}

output "security_group_id" {
  description = "Security group ID for WorkSpaces"
  value       = aws_security_group.workspaces.id
}

output "ip_group_id" {
  description = "IP access control group ID"
  value       = aws_workspaces_ip_group.trusted.id
}

output "subnet_ids" {
  description = "Subnet IDs used for WorkSpaces"
  value       = aws_workspaces_directory.this.subnet_ids
}
