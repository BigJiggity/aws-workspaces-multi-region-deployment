# ==============================================================================
# MODULE: MANAGED-AD
# Deploys AWS Managed Microsoft AD (Enterprise Edition) in us-east-2
# ==============================================================================

variable "domain_name" {
  description = "Fully qualified domain name for the directory"
  type        = string
}

variable "netbios_name" {
  description = "NetBIOS name for the directory"
  type        = string
}

variable "edition" {
  description = "Directory edition (Standard or Enterprise)"
  type        = string
  default     = "Enterprise"
}

variable "vpc_id" {
  description = "VPC ID where the directory will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the directory (2 required, different AZs)"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "landing_zone_cidr" {
  description = "Landing zone CIDR for cross-region access and WorkSpaces traffic"
  type        = string
}

variable "workspaces_cidr" {
  description = "CIDR block for WorkSpaces subnets (typically same as landing_zone_cidr)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Random password for AD admin
resource "random_password" "admin" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*()_+-=[]{}|"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

# Secrets Manager for admin password
resource "aws_secretsmanager_secret" "ad_admin" {
  name                    = "org-workspaces-vdi/managed-ad/admin-password"
  description             = "Admin password for ${var.domain_name} Managed AD"
  recovery_window_in_days = 7
  tags                    = merge(var.tags, { Name = "org-managed-ad-admin-password" })
}

resource "aws_secretsmanager_secret_version" "ad_admin" {
  secret_id = aws_secretsmanager_secret.ad_admin.id
  secret_string = jsonencode({
    username = "Admin"
    password = random_password.admin.result
    domain   = var.domain_name
  })
}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------
locals {
  # Use workspaces_cidr if provided, otherwise use landing_zone_cidr
  workspaces_cidr = var.workspaces_cidr != "" ? var.workspaces_cidr : var.landing_zone_cidr

  # Combined CIDRs that need access to AD
  allowed_cidrs = [var.vpc_cidr, var.landing_zone_cidr]
}

# ------------------------------------------------------------------------------
# SECURITY GROUP: MANAGED AD
# Allows AD traffic from local VPC, cross-region VPC, and WorkSpaces
# ------------------------------------------------------------------------------
resource "aws_security_group" "managed_ad" {
  name        = "org-managed-ad-sg"
  description = "Security group for AWS Managed Microsoft AD - allows all AD protocols"
  vpc_id      = var.vpc_id

  # ============================================================================
  # INBOUND RULES - Active Directory Protocols
  # These rules allow AD traffic from:
  #   1. Local VPC (10.0.0.0/16) - for AD Connect and local services
  #   2. Landing Zone VPC (10.2.0.0/16) - for AD Replica and WorkSpaces
  # ============================================================================

  # DNS - Domain Name System (TCP and UDP)
  dynamic "ingress" {
    for_each = [
      { port = 53, proto = "tcp", desc = "DNS TCP" },
      { port = 53, proto = "udp", desc = "DNS UDP" },
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.proto
      cidr_blocks = local.allowed_cidrs
    }
  }

  # Kerberos - Primary authentication protocol
  dynamic "ingress" {
    for_each = [
      { port = 88, proto = "tcp", desc = "Kerberos TCP" },
      { port = 88, proto = "udp", desc = "Kerberos UDP" },
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.proto
      cidr_blocks = local.allowed_cidrs
    }
  }

  # NTP - Network Time Protocol (critical for Kerberos)
  ingress {
    description = "NTP"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = local.allowed_cidrs
  }

  # RPC Endpoint Mapper
  ingress {
    description = "RPC Endpoint Mapper"
    from_port   = 135
    to_port     = 135
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  # LDAP - Lightweight Directory Access Protocol
  dynamic "ingress" {
    for_each = [
      { port = 389, proto = "tcp", desc = "LDAP TCP" },
      { port = 389, proto = "udp", desc = "LDAP UDP" },
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.proto
      cidr_blocks = local.allowed_cidrs
    }
  }

  # SMB - Server Message Block (file sharing, GPO)
  ingress {
    description = "SMB"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  # Kerberos Password Change
  dynamic "ingress" {
    for_each = [
      { port = 464, proto = "tcp", desc = "Kerberos Password Change TCP" },
      { port = 464, proto = "udp", desc = "Kerberos Password Change UDP" },
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.proto
      cidr_blocks = local.allowed_cidrs
    }
  }

  # LDAPS - LDAP over TLS
  ingress {
    description = "LDAPS"
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  # Global Catalog - Forest-wide directory searches
  ingress {
    description = "Global Catalog (LDAP)"
    from_port   = 3268
    to_port     = 3268
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    description = "Global Catalog (LDAPS)"
    from_port   = 3269
    to_port     = 3269
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  # RPC Dynamic Ports - Used by various AD services
  ingress {
    description = "RPC Dynamic Ports"
    from_port   = 49152
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  # ============================================================================
  # OUTBOUND RULES - Allow all outbound
  # ============================================================================
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name        = "org-managed-ad-sg"
    Description = "Primary Managed AD security group with full protocol support"
  })
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "ad_logs" {
  name              = "/aws/directoryservice/${var.domain_name}"
  retention_in_days = 365
  tags              = merge(var.tags, { Name = "org-managed-ad-logs" })
}

# Data source for current region and account
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# CloudWatch Logs resource policy for Directory Service
# Directory Service requires a resource-based policy, not an IAM role
resource "aws_cloudwatch_log_resource_policy" "ad_logs" {
  policy_name = "org-managed-ad-log-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DSLogSubscriptionWrite"
        Effect = "Allow"
        Principal = {
          Service = "ds.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.ad_logs.arn}:*"
      }
    ]
  })
}

# Managed AD Directory
resource "aws_directory_service_directory" "this" {
  name     = var.domain_name
  password = random_password.admin.result
  edition  = var.edition
  type     = "MicrosoftAD"

  vpc_settings {
    vpc_id     = var.vpc_id
    subnet_ids = length(var.subnet_ids) >= 2 ? slice(var.subnet_ids, 0, 2) : var.subnet_ids
  }

  tags = merge(var.tags, { Name = "org-managed-ad-${var.netbios_name}" })
}

# Log subscription
resource "aws_directory_service_log_subscription" "this" {
  directory_id   = aws_directory_service_directory.this.id
  log_group_name = aws_cloudwatch_log_group.ad_logs.name

  depends_on = [aws_cloudwatch_log_resource_policy.ad_logs]
}

# Wait for AD availability
resource "time_sleep" "wait_for_ad" {
  depends_on      = [aws_directory_service_directory.this]
  create_duration = "5m"
}
