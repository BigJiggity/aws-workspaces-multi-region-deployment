# ==============================================================================
# OUTPUTS - Helpful information after apply
# ==============================================================================

output "s3_bucket_name" {
  description = "Name of the existing S3 bucket used for Terraform state"
  value       = data.aws_s3_bucket.state.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for state locking"
  value       = aws_dynamodb_table.lock.name
}

output "backend_config" {
  description = "Ready-to-use backend configuration block for your Terraform projects"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${data.aws_s3_bucket.state.bucket}"
        key            = "global/terraform.tfstate"
        region         = "${var.region}"
        dynamodb_table = "${aws_dynamodb_table.lock.name}"
        encrypt        = true
      }
    }
  EOT
}