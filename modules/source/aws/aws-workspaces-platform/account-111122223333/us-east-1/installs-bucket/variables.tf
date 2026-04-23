# ==============================================================================
# INPUT VARIABLES - Installs S3 Bucket
# ==============================================================================

variable "region" {
  description = "AWS region"
  type        = string
}

variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for WorkSpaces installs"
  type        = string
}

variable "tags" {
  description = "Standard tags"
  type        = map(string)
}
