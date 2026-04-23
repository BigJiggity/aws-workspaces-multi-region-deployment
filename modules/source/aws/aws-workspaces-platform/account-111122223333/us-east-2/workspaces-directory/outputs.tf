# Outputs for directory registration.

output "directory_id" {
  description = "Directory ID registered with WorkSpaces"
  value       = aws_workspaces_directory.this.directory_id
}
