# ==============================================================================
# DATA SOURCES & EXISTING RESOURCES
# ==============================================================================

# Reference the pre-existing S3 bucket instead of creating it
data "aws_s3_bucket" "state" {
  bucket = var.s3_bucket_name
}

# ==============================================================================
# S3 BUCKET CONFIGURATION (enforced on existing bucket)
# ==============================================================================

# Enable versioning - critical for state file recovery
resource "aws_s3_bucket_versioning" "state" {
  bucket = data.aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce server-side encryption (AES256) on all objects
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = data.aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access - security best practice
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = data.aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==============================================================================
# DYNAMODB LOCK TABLE
# ==============================================================================

# DynamoDB table used for Terraform state locking (prevents concurrent applies)
resource "aws_dynamodb_table" "lock" {
  name         = "org-terraform-state-account-111122223333"
  billing_mode = "PAY_PER_REQUEST" # Cost-effective, no provisioned throughput
  hash_key     = "LockID"

  # Define the primary key attribute
  attribute {
    name = "LockID"
    type = "S" # String type
  }

  # Apply rich, consistent tagging
  tags = local.common_tags
}

# ==============================================================================
# COMMON TAGS (best practice tagging strategy)
# ==============================================================================

locals {
  common_tags = {
    Name                = "org-terraform-state-account-111122223333"
    Project             = "Systems Architecture"
    Environment         = "account-111122223333"
    ManagedBy           = "Terraform"
    Owner               = "Systems Architecture Team"
    CostCenter          = "Infrastructure"
    Confidentiality     = "High"
    Backup              = "Yes"
    Purpose             = "Terraform State Management"
    "terraform-backend" = "true"
  }
}