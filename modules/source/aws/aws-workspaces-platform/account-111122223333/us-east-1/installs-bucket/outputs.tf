# Outputs for installs bucket.

output "bucket_name" {
  description = "Installs bucket name"
  value       = aws_s3_bucket.installs.id
}
