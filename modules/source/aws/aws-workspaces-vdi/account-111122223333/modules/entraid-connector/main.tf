# ==============================================================================
# MODULE: ENTRAID-CONNECTOR
# EC2 instance for Azure AD Connect (EntraID sync)
# ==============================================================================

variable "directory_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "ad_dns_ips" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "entraid_tenant_id" {
  type    = string
  default = ""
}

variable "entraid_app_id" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "key_pair_name" {
  description = "EC2 key pair name for Windows password retrieval. If empty, a new key pair will be created."
  type        = string
  default     = ""
}

variable "enable_session_encryption" {
  description = "Enable KMS encryption for Session Manager sessions"
  type        = bool
  default     = true
}

variable "enable_session_logging" {
  description = "Enable S3 and CloudWatch logging for Session Manager sessions"
  type        = bool
  default     = true
}

variable "session_log_retention_days" {
  description = "Number of days to retain Session Manager logs in CloudWatch"
  type        = number
  default     = 90
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Create key pair if not provided
resource "tls_private_key" "ad_connect" {
  count     = var.key_pair_name == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ad_connect" {
  count      = var.key_pair_name == "" ? 1 : 0
  key_name   = "org-ad-connect-keypair"
  public_key = tls_private_key.ad_connect[0].public_key_openssh
  tags       = var.tags
}

# Store private key in Secrets Manager
resource "aws_secretsmanager_secret" "ad_connect_key" {
  count                   = var.key_pair_name == "" ? 1 : 0
  name                    = "org-workspaces-vdi/ad-connect/private-key"
  description             = "Private key for AD Connect EC2 instance"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "ad_connect_key" {
  count         = var.key_pair_name == "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.ad_connect_key[0].id
  secret_string = tls_private_key.ad_connect[0].private_key_pem
}

locals {
  key_pair_name = var.key_pair_name != "" ? var.key_pair_name : aws_key_pair.ad_connect[0].key_name
}

# Latest Windows Server 2022 AMI
data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group
resource "aws_security_group" "ad_connect" {
  name        = "org-ad-connect-sg"
  description = "Security group for AD Connect server"
  vpc_id      = var.vpc_id

  ingress {
    description = "RDP from VPC"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "org-ad-connect-sg" })
}

# IAM role for SSM
resource "aws_iam_role" "ad_connect" {
  name = "org-ad-connect-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ad_connect.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ds" {
  role       = aws_iam_role.ad_connect.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

# ==============================================================================
# KMS KEY FOR SESSION MANAGER ENCRYPTION
# ==============================================================================
resource "aws_kms_key" "session_manager" {
  count                   = var.enable_session_encryption ? 1 : 0
  description             = "KMS key for Session Manager encryption"
  deletion_window_in_days = 14
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
        Sid    = "Allow Session Manager to use the key"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.id}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      },
      {
        Sid    = "Allow EC2 instances to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ad_connect.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "org-session-manager-kms-key"
  })
}

resource "aws_kms_alias" "session_manager" {
  count         = var.enable_session_encryption ? 1 : 0
  name          = "alias/org-session-manager"
  target_key_id = aws_kms_key.session_manager[0].key_id
}

# IAM policy for KMS access
resource "aws_iam_role_policy" "ssm_kms" {
  count = var.enable_session_encryption ? 1 : 0
  name  = "ssm-kms-access"
  role  = aws_iam_role.ad_connect.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.session_manager[0].arn
      }
    ]
  })
}

# ==============================================================================
# SESSION MANAGER LOGGING - S3 BUCKET
# ==============================================================================
resource "aws_s3_bucket" "session_logs" {
  count  = var.enable_session_logging ? 1 : 0
  bucket = "org-session-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "org-session-logs"
  })
}

resource "aws_s3_bucket_versioning" "session_logs" {
  count  = var.enable_session_logging ? 1 : 0
  bucket = aws_s3_bucket.session_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "session_logs" {
  count  = var.enable_session_logging && var.enable_session_encryption ? 1 : 0
  bucket = aws_s3_bucket.session_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.session_manager[0].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "session_logs" {
  count  = var.enable_session_logging ? 1 : 0
  bucket = aws_s3_bucket.session_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "session_logs" {
  count  = var.enable_session_logging ? 1 : 0
  bucket = aws_s3_bucket.session_logs[0].id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = var.session_log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ==============================================================================
# SESSION MANAGER LOGGING - CLOUDWATCH LOG GROUP
# ==============================================================================
resource "aws_cloudwatch_log_group" "session_logs" {
  count             = var.enable_session_logging ? 1 : 0
  name              = "/aws/ssm/session-manager"
  retention_in_days = var.session_log_retention_days
  kms_key_id        = var.enable_session_encryption ? aws_kms_key.session_manager[0].arn : null

  tags = merge(var.tags, {
    Name = "org-session-manager-logs"
  })
}

# ==============================================================================
# IAM POLICY FOR SESSION LOGGING (S3 + CLOUDWATCH)
# ==============================================================================
resource "aws_iam_role_policy" "ssm_logging" {
  count = var.enable_session_logging ? 1 : 0
  name  = "ssm-session-logging"
  role  = aws_iam_role.ad_connect.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = [
          aws_s3_bucket.session_logs[0].arn,
          "${aws_s3_bucket.session_logs[0].arn}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.session_logs[0].arn,
          "${aws_cloudwatch_log_group.session_logs[0].arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ad_connect" {
  name = "org-ad-connect-profile"
  role = aws_iam_role.ad_connect.name
  tags = var.tags
}

# EC2 Instance
resource "aws_instance" "ad_connect" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ad_connect.name
  vpc_security_group_ids = [aws_security_group.ad_connect.id]
  key_name               = local.key_pair_name
  get_password_data      = true

  root_block_device {
    volume_size           = 100
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data_base64 = base64encode(<<-EOF
    <powershell>
    $dnsServers = @("${join("\",\"", var.ad_dns_ips)}")
    $adapter = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'}
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $dnsServers
    Rename-Computer -NewName "ADCONNECT01" -Force
    Install-WindowsFeature -Name RSAT-AD-Tools -IncludeAllSubFeature
    @"
Azure AD Connect Setup Guide
============================
Domain: ${var.domain_name}
Tenant ID: ${var.entraid_tenant_id}

1. Download Azure AD Connect
2. Run installer as domain admin
3. Configure sync settings
"@ | Out-File "C:\Users\Public\Desktop\Setup.txt"
    shutdown /r /t 300
    </powershell>
  EOF
  )

  tags = merge(var.tags, { Name = "org-ad-connect-server" })

  lifecycle {
    ignore_changes = [ami]
  }
}

# SSM Document for domain join
resource "aws_ssm_document" "domain_join" {
  name            = "org-ad-connect-domain-join"
  document_type   = "Command"
  document_format = "YAML"
  content         = <<-EOF
    schemaVersion: '2.2'
    description: Join AD Connect server to domain
    mainSteps:
      - action: aws:domainJoin
        name: domainJoin
        inputs:
          directoryId: ${var.directory_id}
          directoryName: ${var.domain_name}
          dnsIpAddresses:
            - ${var.ad_dns_ips[0]}
            - ${length(var.ad_dns_ips) > 1 ? var.ad_dns_ips[1] : var.ad_dns_ips[0]}
  EOF
  tags            = var.tags
}

resource "aws_ssm_association" "domain_join" {
  name = aws_ssm_document.domain_join.name
  targets {
    key    = "InstanceIds"
    values = [aws_instance.ad_connect.id]
  }
  depends_on = [aws_instance.ad_connect]
}

# ==============================================================================
# SESSION MANAGER PREFERENCES
# Configures Session Manager with KMS encryption and logging for all sessions
# Note: SSM-SessionManagerRunShell is the default Session Manager preferences document.
# If this fails with "DocumentAlreadyExists", delete it first:
#   aws ssm delete-document --name SSM-SessionManagerRunShell --region us-east-2
# ==============================================================================
resource "aws_ssm_document" "session_manager_prefs" {
  count           = var.enable_session_encryption ? 1 : 0
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager preferences with KMS encryption and logging"
    sessionType   = "Standard_Stream"
    inputs = {
      kmsKeyId                    = aws_kms_key.session_manager[0].arn
      s3BucketName                = var.enable_session_logging ? aws_s3_bucket.session_logs[0].id : ""
      s3KeyPrefix                 = var.enable_session_logging ? "session-logs/" : ""
      s3EncryptionEnabled         = var.enable_session_encryption
      cloudWatchLogGroupName      = var.enable_session_logging ? aws_cloudwatch_log_group.session_logs[0].name : ""
      cloudWatchEncryptionEnabled = var.enable_session_encryption
      cloudWatchStreamingEnabled  = var.enable_session_logging
      idleSessionTimeout          = "20"
      maxSessionDuration          = "60"
      runAsEnabled                = false
      runAsDefaultUser            = ""
      shellProfile = {
        windows = "date"
        linux   = ""
      }
    }
  })

  tags = merge(var.tags, {
    Name = "SSM-SessionManagerRunShell"
  })

  depends_on = [
    aws_s3_bucket.session_logs,
    aws_cloudwatch_log_group.session_logs
  ]
}
