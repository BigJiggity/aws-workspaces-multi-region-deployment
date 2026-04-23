# ==============================================================================
# OUTPUTS - Backend Infrastructure
# ==============================================================================

output "state_bucket_name" {
  description = "S3 bucket name used for Terraform state"
  value       = aws_s3_bucket.state.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.lock.name
}

output "state_kms_key_arn" {
  description = "KMS key ARN for state encryption"
  value       = aws_kms_key.state.arn
}

output "backend_config" {
  description = "Backend config block for Terragrunt"
  value = {
    bucket         = aws_s3_bucket.state.id
    key            = "${var.state_key_prefix}/workspaces.tfstate"
    region         = var.region
    dynamodb_table = aws_dynamodb_table.lock.name
    encrypt        = true
    kms_key_id     = var.kms_alias
  }
}
