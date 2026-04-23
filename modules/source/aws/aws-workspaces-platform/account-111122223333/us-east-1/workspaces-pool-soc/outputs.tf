# Outputs for WorkSpaces SOC pool.

output "pool_id" {
  description = "WorkSpaces pool ID"
  value       = data.aws_cloudformation_stack.workspaces_pooled.outputs["PoolId"]
}

output "pool_arn" {
  description = "WorkSpaces pool ARN (null when not returned by stack outputs)"
  value       = lookup(data.aws_cloudformation_stack.workspaces_pooled.outputs, "PoolArn", null)
}

output "min_user_sessions" {
  description = "Registered minimum user sessions for pool scaling"
  value       = var.min_user_sessions
}

output "max_user_sessions" {
  description = "Registered maximum user sessions for pool scaling"
  value       = var.max_user_sessions
}
