# ==============================================================================
# MODULE: ENTRAID-SYNC
# Syncs users from Microsoft Entra ID to AWS Managed AD
# Uses Microsoft Graph API to read users and AWS Directory Service to create them
# ==============================================================================

# ------------------------------------------------------------------------------
# VARIABLES
# ------------------------------------------------------------------------------
variable "directory_id" {
  description = "AWS Managed AD Directory ID"
  type        = string
}

variable "entra_tenant_id" {
  description = "Microsoft Entra ID (Azure AD) Tenant ID"
  type        = string
}

variable "entra_client_id" {
  description = "Microsoft Entra ID App Registration Client ID"
  type        = string
}

variable "entra_client_secret" {
  description = "Microsoft Entra ID App Registration Client Secret"
  type        = string
  sensitive   = true
}

variable "sync_schedule" {
  description = "CloudWatch Events schedule expression for sync frequency"
  type        = string
  default     = "rate(15 minutes)" # Every 15 minutes
}

variable "entra_group_filter" {
  description = "Entra ID group name to filter users for sync (empty = all users)"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID where Lambda will run (must have connectivity to Managed AD)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda function (private subnets with NAT gateway access)"
  type        = list(string)
}

variable "ad_dns_ips" {
  description = "DNS IPs of the Managed AD domain controllers"
  type        = list(string)
}

variable "domain_name" {
  description = "AD domain name (e.g., corp.example.internal)"
  type        = string
}

variable "ad_admin_secret_arn" {
  description = "ARN of Secrets Manager secret containing AD admin credentials"
  type        = string
}

variable "default_ou" {
  description = "Default OU for new users (e.g., OU=Users,OU=corp,DC=example,DC=internal)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# SECRETS MANAGER - ENTRA ID CREDENTIALS
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "entra_credentials" {
  name                    = "org-entraid-sync/credentials"
  description             = "Microsoft Entra ID credentials for user sync"
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name = "org-entraid-sync-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "entra_credentials" {
  secret_id = aws_secretsmanager_secret.entra_credentials.id
  secret_string = jsonencode({
    tenant_id     = var.entra_tenant_id
    client_id     = var.entra_client_id
    client_secret = var.entra_client_secret
  })
}

# ------------------------------------------------------------------------------
# IAM ROLE FOR LAMBDA
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "org-entraid-sync-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = merge(var.tags, {
    Name = "org-entraid-sync-lambda-role"
  })
}

data "aws_iam_policy_document" "lambda_permissions" {
  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:*"]
  }

  # VPC permissions for Lambda
  statement {
    sid    = "VPCAccess"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }

  # Secrets Manager access
  statement {
    sid    = "SecretsManagerAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      aws_secretsmanager_secret.entra_credentials.arn,
      var.ad_admin_secret_arn
    ]
  }

  # Directory Service permissions
  statement {
    sid    = "DirectoryServiceAccess"
    effect = "Allow"
    actions = [
      "ds:DescribeDirectories",
      "ds:CreateUser",
      "ds:DeleteUser",
      "ds:ResetUserPassword",
      "ds:DescribeUsers",
      "ds:ListUsers"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "org-entraid-sync-lambda-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# ------------------------------------------------------------------------------
# SECURITY GROUP FOR LAMBDA
# ------------------------------------------------------------------------------
resource "aws_security_group" "lambda" {
  name        = "org-entraid-sync-lambda-sg"
  description = "Security group for Entra ID sync Lambda function"
  vpc_id      = var.vpc_id

  # LDAP to AD
  egress {
    description = "LDAP to AD"
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = [for ip in var.ad_dns_ips : "${ip}/32"]
  }

  # LDAPS to AD
  egress {
    description = "LDAPS to AD"
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = [for ip in var.ad_dns_ips : "${ip}/32"]
  }

  # Kerberos to AD
  egress {
    description = "Kerberos TCP to AD"
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = [for ip in var.ad_dns_ips : "${ip}/32"]
  }

  egress {
    description = "Kerberos UDP to AD"
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = [for ip in var.ad_dns_ips : "${ip}/32"]
  }

  # DNS to AD
  egress {
    description = "DNS TCP to AD"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [for ip in var.ad_dns_ips : "${ip}/32"]
  }

  egress {
    description = "DNS UDP to AD"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [for ip in var.ad_dns_ips : "${ip}/32"]
  }

  # SMB to AD
  egress {
    description = "SMB to AD"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = [for ip in var.ad_dns_ips : "${ip}/32"]
  }

  # HTTPS for Microsoft Graph API and AWS APIs
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "org-entraid-sync-lambda-sg"
  })
}

# ------------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/org-entraid-sync"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "org-entraid-sync-logs"
  })
}

# ------------------------------------------------------------------------------
# LAMBDA FUNCTION
# ------------------------------------------------------------------------------
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "sync" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "org-entraid-sync"
  role             = aws_iam_role.lambda.arn
  handler          = "sync_users.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = 300 # 5 minutes
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENTRA_SECRET_ARN   = aws_secretsmanager_secret.entra_credentials.arn
      AD_SECRET_ARN      = var.ad_admin_secret_arn
      DIRECTORY_ID       = var.directory_id
      DOMAIN_NAME        = var.domain_name
      ENTRA_GROUP_FILTER = var.entra_group_filter
      DEFAULT_OU         = var.default_ou
      AD_DNS_IPS         = join(",", var.ad_dns_ips)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda_permissions
  ]

  tags = merge(var.tags, {
    Name = "org-entraid-sync"
  })
}

# ------------------------------------------------------------------------------
# LAMBDA LAYER FOR DEPENDENCIES
# Install: pip install msal ldap3 -t python/
# ------------------------------------------------------------------------------
resource "aws_lambda_layer_version" "dependencies" {
  filename            = "${path.module}/lambda_layer.zip"
  layer_name          = "org-entraid-sync-dependencies"
  compatible_runtimes = ["python3.11"]
  description         = "Dependencies for Entra ID sync (msal, ldap3)"

  # This will fail if lambda_layer.zip doesn't exist
  # See instructions below for creating the layer
  lifecycle {
    create_before_destroy = true
  }
}

# Attach layer to function
resource "aws_lambda_function" "sync_with_layer" {
  count = 0 # Disabled - using inline dependencies approach instead

  filename         = data.archive_file.lambda.output_path
  function_name    = "org-entraid-sync"
  role             = aws_iam_role.lambda.arn
  handler          = "sync_users.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = 300
  memory_size      = 256
  layers           = [aws_lambda_layer_version.dependencies.arn]

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENTRA_SECRET_ARN   = aws_secretsmanager_secret.entra_credentials.arn
      AD_SECRET_ARN      = var.ad_admin_secret_arn
      DIRECTORY_ID       = var.directory_id
      DOMAIN_NAME        = var.domain_name
      ENTRA_GROUP_FILTER = var.entra_group_filter
      DEFAULT_OU         = var.default_ou
    }
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# EVENTBRIDGE RULE - SCHEDULED SYNC
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "sync_schedule" {
  name                = "org-entraid-sync-schedule"
  description         = "Triggers Entra ID to Managed AD user sync"
  schedule_expression = var.sync_schedule

  tags = merge(var.tags, {
    Name = "org-entraid-sync-schedule"
  })
}

resource "aws_cloudwatch_event_target" "sync_lambda" {
  rule      = aws_cloudwatch_event_rule.sync_schedule.name
  target_id = "EntraIDSyncLambda"
  arn       = aws_lambda_function.sync.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sync.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sync_schedule.arn
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------
output "lambda_function_name" {
  description = "Name of the sync Lambda function"
  value       = aws_lambda_function.sync.function_name
}

output "lambda_function_arn" {
  description = "ARN of the sync Lambda function"
  value       = aws_lambda_function.sync.arn
}

output "entra_secret_arn" {
  description = "ARN of the Entra ID credentials secret"
  value       = aws_secretsmanager_secret.entra_credentials.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group for sync logs"
  value       = aws_cloudwatch_log_group.lambda.name
}
