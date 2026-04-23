# ==============================================================================
# VAULTWARDEN DEPLOYMENT
# Region: us-east-2 (Ohio)
# Account: account-111122223333 (111122223333)
#
# Deploys VaultWarden (Bitwarden-compatible password manager) on ECS Fargate
# with PostgreSQL RDS backend, fronted by ALB with WAF protection.
#
# Architecture:
#   Internet → WAF → ALB (public) → Network Firewall → ECS Fargate (private) → RDS
#
# Prerequisites:
#   - Existing VPC from org-aws-networking project
#   - Network Firewall deployed and routing configured
#   - Transit Gateway for cross-region connectivity
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }

  backend "s3" {
    bucket         = "org-terraform-state-account-111122223333-111122223333"
    key            = "vaultwarden/us-east-2/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "org-terraform-state-account-111122223333"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      Application = "vaultwarden"
    }
  }
}

# ------------------------------------------------------------------------------
# DATA SOURCES - Existing Infrastructure
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Get VPC from networking project
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Get private subnets for ECS and RDS
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

# Get public subnets for ALB
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
}

# Get individual subnet details for AZ mapping
data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------
locals {
  name_prefix = "org-vw"

  common_tags = {
    Component = "vaultwarden"
    FQDN      = var.fqdn
  }

  # Database connection string (built from components)
  database_url = "postgresql://${var.db_username}:${random_password.db_password.result}@${aws_db_instance.vaultwarden.endpoint}/${var.db_name}"

  # Container port
  container_port = 8080

  # WebSocket port (for real-time sync)
  websocket_port = 3012
}
