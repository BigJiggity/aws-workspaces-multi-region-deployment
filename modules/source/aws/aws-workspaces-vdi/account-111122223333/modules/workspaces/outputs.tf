# ==============================================================================
# MODULE OUTPUTS: WORKSPACES
# ==============================================================================

output "workspace_ids" {
  description = "Map of username to WorkSpaces instance ID"
  value = {
    for username, workspace in aws_workspaces_workspace.this :
    username => workspace.id
  }
}

output "computer_names" {
  description = "Map of username to WorkSpaces computer name"
  value = {
    for username, workspace in aws_workspaces_workspace.this :
    username => workspace.computer_name
  }
}

output "ip_addresses" {
  description = "Map of username to WorkSpaces IP address"
  value = {
    for username, workspace in aws_workspaces_workspace.this :
    username => workspace.ip_address
  }
}

output "workspace_states" {
  description = "Map of username to WorkSpaces state"
  value = {
    for username, workspace in aws_workspaces_workspace.this :
    username => workspace.state
  }
}

output "bundle_id" {
  description = "Bundle ID used for WorkSpaces"
  value       = local.bundle_id
}

output "running_mode" {
  description = "Running mode for WorkSpaces"
  value       = var.running_mode
}

output "users_provisioned" {
  description = "List of users with WorkSpaces"
  value       = var.users
}

output "alarm_arns" {
  description = "Map of username to CloudWatch alarm ARN"
  value = {
    for username, alarm in aws_cloudwatch_metric_alarm.unhealthy :
    username => alarm.arn
  }
}
