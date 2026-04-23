# ==============================================================================
# BACKEND INFRASTRUCTURE: S3 + DynamoDB + KMS
# ==============================================================================

# Preflight checks to fail fast on missing backend inputs.
resource "null_resource" "preflight" {
  triggers = {
    state_bucket_name   = var.state_bucket_name
    dynamodb_table_name = var.dynamodb_table_name
  }

  lifecycle {
    # Ensure naming inputs are explicitly set so state resources are deterministic.
    precondition {
      condition     = var.state_bucket_name != ""
      error_message = "state_bucket_name must be set."
    }
    precondition {
      condition     = var.dynamodb_table_name != ""
      error_message = "dynamodb_table_name must be set."
    }
  }
}

# KMS key for encrypting Terraform state objects and DynamoDB at rest.
resource "aws_kms_key" "state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-kms-terraform-state"
  })
}

# Stable alias for the KMS key.
resource "aws_kms_alias" "state" {
  name          = var.kms_alias
  target_key_id = aws_kms_key.state.key_id
}

# S3 bucket for Terraform state.
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-terraform-state-bucket"
    Purpose = "Terraform State"
  })
}

# Enable bucket versioning to retain state history.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce KMS encryption for all objects.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
  }
}

# Block all public access to the bucket.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce bucket owner control over all objects (ACLs disabled).
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Deny non-TLS access to the bucket.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# DynamoDB table for state locking.
resource "aws_dynamodb_table" "lock" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.state.arn
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-terraform-locks"
    Purpose = "Terraform State Locking"
  })
}
