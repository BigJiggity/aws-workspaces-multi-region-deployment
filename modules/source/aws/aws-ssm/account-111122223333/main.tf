# ==============================================================================
# ROOT MODULE: Generic SSM VPC Endpoints - US-East-2
# Project: org-ssm-endpoints-us-east-2
#
# Architecture Overview:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         VPC: 10.0.0.0/16 (us-east-2)                         │
# │                                                                             │
# │  ┌──────────────────────────────────────────────────────────────────────┐  │
# │  │                    MANAGEMENT TIER (SSM Endpoints)                    │  │
# │  │                                                                        │  │
# │  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │  │
# │  │  │ management-2a   │  │ management-2b   │  │ management-2c   │       │  │
# │  │  │ 10.0.12.0/24     │  │ 10.0.13.0/24     │  │ 10.0.14.0/24     │       │  │
# │  │  │ us-east-2a      │  │ us-east-2b      │  │ us-east-2c      │       │  │
# │  │  │                 │  │                 │  │                 │       │  │
# │  │  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │       │  │
# │  │  │ │ SSM ENI     │ │  │ │ SSM ENI     │ │  │ │ SSM ENI     │ │       │  │
# │  │  │ │ SSMMessages │ │  │ │ SSMMessages │ │  │ │ SSMMessages │ │       │  │
# │  │  │ │ EC2Messages │ │  │ │ EC2Messages │ │  │ │ EC2Messages │ │       │  │
# │  │  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │       │  │
# │  │  └─────────────────┘  └─────────────────┘  └─────────────────┘       │  │
# │  │                                                                        │  │
# │  └──────────────────────────────────────────────────────────────────────┘  │
# │                                                                             │
# │  Endpoints enable Session Manager access without NAT Gateway:              │
# │    • com.amazonaws.us-east-2.ssm          (Systems Manager API)            │
# │    • com.amazonaws.us-east-2.ssmmessages  (Session Manager transport)      │
# │    • com.amazonaws.us-east-2.ec2messages  (SSM Agent commands)             │
# │                                                                             │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# Prerequisites:
#   - org-vpc_firewall_us-east-2-account-111122223333 deployed with management subnets
#
# Deployed: December 2025
# ==============================================================================

# ------------------------------------------------------------------------------
# DATA SOURCE: US-East-2 VPC/Firewall Remote State
# Retrieves VPC and management subnet information from the deployed
# org-vpc_firewall_us-east-2-account-111122223333 project
# ------------------------------------------------------------------------------
data "terraform_remote_state" "vpc_firewall" {
  backend = "s3"

  config = {
    bucket = var.vpc_firewall_state_bucket
    key    = var.vpc_firewall_state_key
    region = var.vpc_firewall_state_region
  }
}

# ------------------------------------------------------------------------------
# DATA SOURCE: Current AWS Region
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# DATA SOURCE: VPC Details
# Used to automatically determine VPC CIDR if not provided
# ------------------------------------------------------------------------------
data "aws_vpc" "selected" {
  id = local.vpc_id
}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------
locals {
  # VPC and Subnet Configuration from Remote State
  vpc_id             = data.terraform_remote_state.vpc_firewall.outputs.vpc_id
  vpc_cidr           = data.terraform_remote_state.vpc_firewall.outputs.vpc_cidr
  management_subnets = data.terraform_remote_state.vpc_firewall.outputs.management_subnet_ids

  # Common tags for all resources
  common_tags = merge(var.tags, {
    Project     = "org-ssm-endpoints-${var.aws_region}"
    Environment = "account-111122223333"
    Owner       = "system-architects"
    CostCenter  = "CloudArchitecture"
    ManagedBy   = "terraform"
  })
}

# ==============================================================================
# SECURITY GROUP: SSM VPC Endpoints
# Allows HTTPS (443) traffic from within the VPC for SSM communication
# ==============================================================================
resource "aws_security_group" "ssm_endpoints" {
  name        = "${var.name_prefix}-ssm-endpoints-sg"
  description = "Security group for SSM VPC endpoints"
  vpc_id      = local.vpc_id

  # Inbound: Allow HTTPS from VPC CIDR
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  # Outbound: Allow all (endpoints need to respond)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-ssm-endpoints-sg"
  })
}

# ==============================================================================
# VPC ENDPOINT: Systems Manager (SSM)
# Required for SSM API calls (describe instances, send commands, etc.)
# ==============================================================================
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.management_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-ssm-endpoint"
  })
}

# ==============================================================================
# VPC ENDPOINT: SSM Messages
# Required for Session Manager bidirectional communication channel
# ==============================================================================
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.management_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-ssmmessages-endpoint"
  })
}

# ==============================================================================
# VPC ENDPOINT: EC2 Messages
# Required for SSM Agent to receive commands from Systems Manager
# ==============================================================================
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.management_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-ec2messages-endpoint"
  })
}
