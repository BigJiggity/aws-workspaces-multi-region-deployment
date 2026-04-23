# ==============================================================================
# ROOT OUTPUTS
# Project: Generic WorkSpaces VDI - US-East-2 Deployment
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC INFRASTRUCTURE (from remote state)
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID for WorkSpaces infrastructure in us-east-2"
  value       = local.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = local.vpc_cidr
}

output "management_subnet_ids" {
  description = "Management subnet IDs in us-east-2"
  value       = local.management_subnets
}

output "private_subnet_ids" {
  description = "Private subnet IDs for WorkSpaces deployment"
  value       = local.private_subnets
}

# ------------------------------------------------------------------------------
# SELF-MANAGED AD (from account-111122223333)
# ------------------------------------------------------------------------------
output "dc01_private_ip" {
  description = "Private IP of DC01 (us-east-2a)"
  value       = local.dc01_ip
}

output "dc02_private_ip" {
  description = "Private IP of DC02 (us-east-2b)"
  value       = local.dc02_ip
}

output "ad_dns_ips_for_connector" {
  description = "DNS IPs used for AD Connector"
  value       = local.dns_ips_for_connector
}

# ------------------------------------------------------------------------------
# TRANSIT GATEWAY
# ------------------------------------------------------------------------------
output "transit_gateway_id" {
  description = "Transit Gateway ID in us-east-2"
  value       = local.tgw_id
}

# ------------------------------------------------------------------------------
# AD CONNECTOR OUTPUTS
# ------------------------------------------------------------------------------
output "ad_connector_id" {
  description = "AD Connector directory ID"
  value       = module.ad_connector.connector_id
}

output "ad_connector_dns_ips" {
  description = "DNS IPs of the AD Connector"
  value       = module.ad_connector.dns_ip_addresses
}

# ------------------------------------------------------------------------------
# WORKSPACES DIRECTORY OUTPUTS
# ------------------------------------------------------------------------------
output "workspaces_directory_id" {
  description = "WorkSpaces directory ID"
  value       = module.workspaces_directory.directory_id
}

output "workspaces_registration_code" {
  description = "Registration code for WorkSpaces client connections"
  value       = module.workspaces_directory.registration_code
  sensitive   = true
}

output "workspaces_directory_security_group_id" {
  description = "Security group ID for WorkSpaces"
  value       = module.workspaces_directory.security_group_id
}

# ------------------------------------------------------------------------------
# WORKSPACES OUTPUTS
# ------------------------------------------------------------------------------
output "workspaces_ids" {
  description = "Map of username to WorkSpaces instance ID"
  value       = module.workspaces.workspace_ids
}

output "workspaces_computer_names" {
  description = "Map of username to WorkSpaces computer name"
  value       = module.workspaces.computer_names
}

output "workspaces_ip_addresses" {
  description = "Map of username to WorkSpaces IP address"
  value       = module.workspaces.ip_addresses
}

output "workspaces_bundle_id" {
  description = "WorkSpaces bundle ID used"
  value       = module.workspaces.bundle_id
}

# ------------------------------------------------------------------------------
# DEPLOYMENT SUMMARY
# ------------------------------------------------------------------------------
output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    ad_domain        = var.ad_domain_name
    ad_netbios       = var.ad_netbios_name
    ad_type          = "Self-Managed"
    region           = "us-east-2"
    dc01_ip          = local.dc01_ip
    dc02_ip          = local.dc02_ip
    ad_connector_id  = module.ad_connector.connector_id
    workspaces_count = length(var.workspaces_users)
    workspaces_mode  = var.workspaces_running_mode
  }
}
