# ==============================================================================
# SECRETS MODULE - OUTPUTS
# ==============================================================================

output "db_password_secret_arn" {
  description = "ARN of the database password secret"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_password_secret_name" {
  description = "Name of the database password secret"
  value       = aws_secretsmanager_secret.db_password.name
}

output "admin_token_secret_arn" {
  description = "ARN of the admin token secret"
  value       = var.admin_token_enabled ? aws_secretsmanager_secret.admin_token[0].arn : null
}

output "admin_token_secret_name" {
  description = "Name of the admin token secret"
  value       = var.admin_token_enabled ? aws_secretsmanager_secret.admin_token[0].name : null
}

output "push_installation_id_secret_arn" {
  description = "ARN of the push installation ID secret"
  value       = var.push_installation_id != "" ? aws_secretsmanager_secret.push_installation_id[0].arn : null
}

output "push_installation_key_secret_arn" {
  description = "ARN of the push installation key secret"
  value       = var.push_installation_key != "" ? aws_secretsmanager_secret.push_installation_key[0].arn : null
}

output "smtp_username_secret_arn" {
  description = "ARN of the SMTP username secret"
  value       = var.smtp_username != "" ? aws_secretsmanager_secret.smtp_username[0].arn : null
}

output "smtp_password_secret_arn" {
  description = "ARN of the SMTP password secret"
  value       = var.smtp_password != "" ? aws_secretsmanager_secret.smtp_password[0].arn : null
}

output "secret_arns" {
  description = "List of all secret ARNs"
  value = compact([
    aws_secretsmanager_secret.db_password.arn,
    var.admin_token_enabled ? aws_secretsmanager_secret.admin_token[0].arn : "",
    var.push_installation_id != "" ? aws_secretsmanager_secret.push_installation_id[0].arn : "",
    var.push_installation_key != "" ? aws_secretsmanager_secret.push_installation_key[0].arn : "",
    var.smtp_username != "" ? aws_secretsmanager_secret.smtp_username[0].arn : "",
    var.smtp_password != "" ? aws_secretsmanager_secret.smtp_password[0].arn : "",
  ])
}
