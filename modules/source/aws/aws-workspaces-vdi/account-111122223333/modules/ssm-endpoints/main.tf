# ==============================================================================
# MODULE: SSM-ENDPOINTS
# Deploys VPC Endpoints required for AWS Systems Manager Session Manager
# ==============================================================================

variable "vpc_id" {
  description = "VPC ID where endpoints will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the VPC endpoints"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules. If empty, will be looked up from VPC."
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

data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  vpc_cidr = var.vpc_cidr != "" ? var.vpc_cidr : data.aws_vpc.selected.cidr_block
}

# ------------------------------------------------------------------------------
# SECURITY GROUP FOR VPC ENDPOINTS
# All SSM endpoints require HTTPS (443) access
# ------------------------------------------------------------------------------
resource "aws_security_group" "ssm_endpoints" {
  name        = "org-ssm-endpoints-sg"
  description = "Security group for SSM VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "org-ssm-endpoints-sg"
  })
}

# ------------------------------------------------------------------------------
# VPC ENDPOINT: SSM
# Required for Systems Manager API calls
# ------------------------------------------------------------------------------
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "org-ssm-endpoint"
  })
}

# ------------------------------------------------------------------------------
# VPC ENDPOINT: SSM MESSAGES
# Required for Session Manager message transport
# ------------------------------------------------------------------------------
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "org-ssmmessages-endpoint"
  })
}

# ------------------------------------------------------------------------------
# VPC ENDPOINT: EC2 MESSAGES
# Required for SSM Agent to receive commands
# ------------------------------------------------------------------------------
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "org-ec2messages-endpoint"
  })
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------
output "ssm_endpoint_id" {
  description = "SSM VPC endpoint ID"
  value       = aws_vpc_endpoint.ssm.id
}

output "ssmmessages_endpoint_id" {
  description = "SSM Messages VPC endpoint ID"
  value       = aws_vpc_endpoint.ssmmessages.id
}

output "ec2messages_endpoint_id" {
  description = "EC2 Messages VPC endpoint ID"
  value       = aws_vpc_endpoint.ec2messages.id
}

output "security_group_id" {
  description = "Security group ID for SSM endpoints"
  value       = aws_security_group.ssm_endpoints.id
}

output "endpoint_dns_entries" {
  description = "DNS entries for all SSM endpoints"
  value = {
    ssm         = aws_vpc_endpoint.ssm.dns_entry
    ssmmessages = aws_vpc_endpoint.ssmmessages.dns_entry
    ec2messages = aws_vpc_endpoint.ec2messages.dns_entry
  }
}
