# ==============================================================================
# MODULE: WorkSpaces Installs Bucket
# ==============================================================================

# Preflight checks to fail fast on missing inputs.
resource "null_resource" "preflight" {
  triggers = {
    bucket_name = var.bucket_name
  }

  lifecycle {
    # Ensure bucket name is provided for deterministic naming.
    precondition {
      condition     = var.bucket_name != ""
      error_message = "bucket_name must be set."
    }
  }
}

# S3 bucket used for WorkSpaces install media.
resource "aws_s3_bucket" "installs" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-installs-bucket"
  })
}

resource "aws_s3_bucket_versioning" "installs" {
  bucket = aws_s3_bucket.installs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "installs" {
  bucket = aws_s3_bucket.installs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "installs" {
  bucket                  = aws_s3_bucket.installs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "installs" {
  bucket = aws_s3_bucket.installs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "installs" {
  bucket = aws_s3_bucket.installs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.installs.arn,
          "${aws_s3_bucket.installs.arn}/*"
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
