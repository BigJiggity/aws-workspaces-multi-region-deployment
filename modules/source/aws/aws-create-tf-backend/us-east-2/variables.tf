# ==============================================================================
# INPUT VARIABLES
# ==============================================================================

# AWS region where the backend resources exist/live
variable "region" {
  description = "AWS region for the Terraform state bucket and lock table"
  type        = string
  default     = "us-east-2"
}

# Name of the pre-existing S3 bucket (do not change unless bucket renamed)
variable "s3_bucket_name" {
  description = "Exact name of the already-created S3 bucket for Terraform state"
  type        = string
  default     = "org-terraform-state-account-111122223333-111122223333"
}