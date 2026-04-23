# Outputs for observability and downstream integrations.

output "vpc_id" {
  description = "VPC ID derived from WorkSpaces subnets"
  value       = local.vpc_id
}

output "workspaces_subnet_ids" {
  description = "Subnet IDs used for WorkSpaces"
  value       = local.workspaces_subnet_ids
}

output "directory_id" {
  description = "Directory ID registered with WorkSpaces"
  value       = module.workspaces_directory.directory_id
}

output "workspaces" {
  description = "WorkSpaces created by this deployment"
  value       = module.workspaces.workspaces
}
