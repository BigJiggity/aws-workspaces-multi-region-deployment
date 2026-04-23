# ==============================================================================
# MODULE: WORKSPACES
# Provisions individual AWS WorkSpaces for users
# ==============================================================================

variable "directory_id" {
  type = string
}

variable "bundle_id" {
  type    = string
  default = ""
}

variable "running_mode" {
  type    = string
  default = "AUTO_STOP"
}

variable "auto_stop_timeout" {
  type    = number
  default = 60
}

variable "root_volume_size" {
  type    = number
  default = 80
}

variable "user_volume_size" {
  type    = number
  default = 50
}

variable "compute_type" {
  type    = string
  default = "STANDARD"
}

variable "users" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "volume_encryption_key" {
  description = "KMS key ARN for WorkSpaces volume encryption. If empty, a new key will be created."
  type        = string
  default     = ""
}

variable "enable_encryption" {
  description = "Enable volume encryption for WorkSpaces. Set to false to allow imaging."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# KMS KEY FOR WORKSPACES VOLUME ENCRYPTION
# ------------------------------------------------------------------------------
resource "aws_kms_key" "workspaces" {
  count = var.enable_encryption && var.volume_encryption_key == "" ? 1 : 0

  description             = "KMS key for WorkSpaces volume encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow WorkSpaces Service"
        Effect = "Allow"
        Principal = {
          Service = "workspaces.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "org-workspaces-encryption-key"
  })
}

resource "aws_kms_alias" "workspaces" {
  count = var.enable_encryption && var.volume_encryption_key == "" ? 1 : 0

  name          = "alias/org-workspaces-encryption"
  target_key_id = aws_kms_key.workspaces[0].key_id
}

data "aws_caller_identity" "current" {}

# Default Windows 10 bundle
data "aws_workspaces_bundle" "default" {
  count = var.bundle_id == "" ? 1 : 0
  owner = "AMAZON"
  name  = "Standard with Windows 10 (Server 2019 based)"
}

locals {
  kms_key_arn = var.enable_encryption ? (
    var.volume_encryption_key != "" ? var.volume_encryption_key : aws_kms_key.workspaces[0].arn
  ) : null
  bundle_id = var.bundle_id != "" ? var.bundle_id : (
    length(data.aws_workspaces_bundle.default) > 0 ? data.aws_workspaces_bundle.default[0].id : ""
  )
}

# WorkSpaces instances
resource "aws_workspaces_workspace" "this" {
  for_each = toset(var.users)

  directory_id = var.directory_id
  bundle_id    = local.bundle_id
  user_name    = each.value

  root_volume_encryption_enabled = var.enable_encryption
  user_volume_encryption_enabled = var.enable_encryption
  volume_encryption_key          = var.enable_encryption ? local.kms_key_arn : null

  workspace_properties {
    running_mode                              = var.running_mode
    running_mode_auto_stop_timeout_in_minutes = var.running_mode == "AUTO_STOP" ? var.auto_stop_timeout : null
    root_volume_size_gib                      = var.root_volume_size
    user_volume_size_gib                      = var.user_volume_size
    compute_type_name                         = var.compute_type
  }

  tags = merge(var.tags, {
    Name     = "org-workspace-${each.value}"
    Username = each.value
  })

  lifecycle {
    ignore_changes = [user_name]
  }
}

# CloudWatch alarms for unhealthy WorkSpaces
resource "aws_cloudwatch_metric_alarm" "unhealthy" {
  for_each = toset(var.users)

  alarm_name          = "org-workspace-unhealthy-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Unhealthy"
  namespace           = "AWS/WorkSpaces"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "WorkSpace for ${each.value} is unhealthy"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WorkspaceId = aws_workspaces_workspace.this[each.value].id
  }

  tags = var.tags
}
