# ==============================================================================
# MODULE OUTPUTS: ENTRAID-CONNECTOR
# ==============================================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.ad_connect.id
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.ad_connect.private_ip
}

output "private_dns" {
  description = "Private DNS name"
  value       = aws_instance.ad_connect.private_dns
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.ad_connect.id
}

output "iam_role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.ad_connect.arn
}

output "private_key_secret_arn" {
  description = "Secrets Manager ARN for the private key (use to decrypt Windows password)"
  value       = length(aws_secretsmanager_secret.ad_connect_key) > 0 ? aws_secretsmanager_secret.ad_connect_key[0].arn : null
}

output "password_data" {
  description = "Encrypted Windows administrator password (decrypt with private key)"
  value       = aws_instance.ad_connect.password_data
  sensitive   = true
}

output "connection_instructions" {
  description = "Instructions to connect to the AD Connect server"
  value       = <<-EOF
    AD Connect Server Connection Instructions
    ==========================================
    Instance ID: ${aws_instance.ad_connect.id}
    Private IP:  ${aws_instance.ad_connect.private_ip}
    
    Option 1: SSM Session Manager (Recommended)
    -------------------------------------------
    aws ssm start-session --target ${aws_instance.ad_connect.id} --region us-east-2
    
    Option 2: RDP with Windows Password
    ------------------------------------
    1. Get private key:
       aws secretsmanager get-secret-value --secret-id "org-workspaces-vdi/ad-connect/private-key" --region us-east-2 --query SecretString --output text > ad-connect-key.pem
    
    2. Get encrypted password:
       aws ec2 get-password-data --instance-id ${aws_instance.ad_connect.id} --priv-launch-key ad-connect-key.pem --region us-east-2
    
    3. RDP to ${aws_instance.ad_connect.private_ip} with:
       Username: Administrator
       Password: <from step 2>
    
    After Domain Join:
       Username: ORGCORP\Admin
       Password: <from Secrets Manager: org-workspaces-vdi/managed-ad/admin-password>
  EOF
}

# ------------------------------------------------------------------------------
# KMS KEY OUTPUTS
# ------------------------------------------------------------------------------
output "kms_key_id" {
  description = "KMS key ID for Session Manager encryption"
  value       = length(aws_kms_key.session_manager) > 0 ? aws_kms_key.session_manager[0].key_id : null
}

output "kms_key_arn" {
  description = "KMS key ARN for Session Manager encryption"
  value       = length(aws_kms_key.session_manager) > 0 ? aws_kms_key.session_manager[0].arn : null
}

output "kms_key_alias" {
  description = "KMS key alias for Session Manager encryption"
  value       = length(aws_kms_alias.session_manager) > 0 ? aws_kms_alias.session_manager[0].name : null
}

output "session_encryption_enabled" {
  description = "Whether Session Manager encryption is enabled"
  value       = var.enable_session_encryption
}

# ------------------------------------------------------------------------------
# SESSION LOGGING OUTPUTS
# ------------------------------------------------------------------------------
output "session_logging_enabled" {
  description = "Whether Session Manager logging is enabled"
  value       = var.enable_session_logging
}

output "session_logs_s3_bucket" {
  description = "S3 bucket name for Session Manager logs"
  value       = length(aws_s3_bucket.session_logs) > 0 ? aws_s3_bucket.session_logs[0].id : null
}

output "session_logs_s3_bucket_arn" {
  description = "S3 bucket ARN for Session Manager logs"
  value       = length(aws_s3_bucket.session_logs) > 0 ? aws_s3_bucket.session_logs[0].arn : null
}

output "session_logs_cloudwatch_log_group" {
  description = "CloudWatch Log Group name for Session Manager logs"
  value       = length(aws_cloudwatch_log_group.session_logs) > 0 ? aws_cloudwatch_log_group.session_logs[0].name : null
}

output "session_logs_cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN for Session Manager logs"
  value       = length(aws_cloudwatch_log_group.session_logs) > 0 ? aws_cloudwatch_log_group.session_logs[0].arn : null
}
