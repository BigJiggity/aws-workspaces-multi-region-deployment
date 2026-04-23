# ==============================================================================
# RDS MODULE - OUTPUTS
# ==============================================================================

output "endpoint" {
  description = "RDS endpoint (without port)"
  value       = split(":", aws_db_instance.main.endpoint)[0]
}

output "endpoint_full" {
  description = "RDS endpoint with port"
  value       = aws_db_instance.main.endpoint
}

output "identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption"
  value       = aws_kms_key.rds.arn
}
