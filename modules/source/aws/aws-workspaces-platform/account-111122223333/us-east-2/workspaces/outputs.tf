# Outputs for WorkSpaces instances.

output "workspaces" {
  description = "WorkSpaces created by this module"
  value = {
    for k, ws in aws_workspaces_workspace.this : k => {
      id        = ws.id
      directory = ws.directory_id
      bundle_id = ws.bundle_id
      user_name = ws.user_name
      state     = ws.state
    }
  }
}
