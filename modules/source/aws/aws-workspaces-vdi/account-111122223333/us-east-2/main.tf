# ==============================================================================
# ROOT MODULE: Generic WorkSpaces VDI - US-East-2 Deployment
# Project: org-workspaces-vdi
# Region: us-east-2 (Ohio)
# Updated: December 2025
#
# Architecture Overview:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                        US-EAST-2 (Ohio) – WORKSPACES & DCs                  │
# │  ┌───────────────────────────────────────────────────────────────────────┐  │
# │  │         VPC 10.0.0.0/16 (account-111122223333-vpc / vpc-066b5d5ade267680f) │  │
# │  │                                                                         │  │
# │  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
# │  │  │              Management Subnets                                   │  │  │
# │  │  │                                                                    │  │  │
# │  │  │  ┌──────────────────────┐      ┌──────────────────────┐          │  │  │
# │  │  │  │  DC01 (PDC)          │      │  DC02                │          │  │  │
# │  │  │  │  Windows 2022        │      │  Windows 2022        │          │  │  │
# │  │  │  │  example.internal             │      │  example.internal             │          │  │  │
# │  │  │  │  10.0.12.10           │      │  10.0.13.10           │          │  │  │
# │  │  │  └──────────────────────┘      └──────────────────────┘          │  │  │
# │  │  └──────────────────────────────────────────────────────────────────┘  │  │
# │  │                                                                         │  │
# │  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
# │  │  │              AD Connector + WorkSpaces Directory                  │  │  │
# │  │  │              Points to DC01 + DC02 (local, low-latency)           │  │  │
# │  │  └──────────────────────────────────────────────────────────────────┘  │  │
# │  │                                                                         │  │
# │  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
# │  │  │              Private Subnets - WorkSpaces                         │  │  │
# │  │  │                                                                    │  │  │
# │  │  │     ┌────────────────────────────────────────────────────────┐    │  │  │
# │  │  │     │         AWS WorkSpaces                                  │    │  │  │
# │  │  │     │         Domain-joined to example.internal                        │    │  │  │
# │  │  │     │         Low-latency auth via DC01/DC02                  │    │  │  │
# │  │  │     └────────────────────────────────────────────────────────┘    │  │  │
# │  │  └──────────────────────────────────────────────────────────────────┘  │  │
# │  │                                                                         │  │
# │  │  [Network Firewall] [Transit Gateway] [NAT Gateways]                   │  │
# │  └─────────────────────────────────────────────────────────────────────────┘  │
# └───────────────────────────────────────────────────────────────────────────────┘
#
# Domain: example.internal (Self-Managed AD)
# NetBIOS: `ORG`
#
# Deployment Order:
#   1. org-vpc_firewall_us-east-2-account-111122223333 (VPC/Firewall/TGW in us-east-2)
#   2. account-111122223333 (Domain Controllers)
#   3. THIS PROJECT (AD Connector, WorkSpaces Directory, WorkSpaces)
#
# ==============================================================================

# ------------------------------------------------------------------------------
# DATA SOURCE: US-East-2 VPC/Firewall Remote State
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
# DATA SOURCE: Self-Managed AD Infrastructure Remote State
# From account-111122223333 project
# ------------------------------------------------------------------------------
data "terraform_remote_state" "ad_account_000000000000" {
  backend = "s3"

  config = {
    bucket = var.ad_account_000000000000_state_bucket
    key    = var.ad_account_000000000000_state_key
    region = var.ad_account_000000000000_state_region
  }
}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------
locals {
  # ============================================================================
  # US-EAST-2 VPC
  # ============================================================================
  vpc_id             = data.terraform_remote_state.vpc_firewall.outputs.vpc_id
  vpc_cidr           = data.terraform_remote_state.vpc_firewall.outputs.vpc_cidr
  management_subnets = var.management_subnet_ids
  # Private subnets for WorkSpaces deployment
  # Using specific subnets from account-111122223333-vpc
  private_subnets     = var.workspaces_subnet_ids
  all_route_table_ids = data.terraform_remote_state.vpc_firewall.outputs.all_route_table_ids
  tgw_id              = data.terraform_remote_state.vpc_firewall.outputs.transit_gateway_id
  tgw_route_table_id  = data.terraform_remote_state.vpc_firewall.outputs.transit_gateway_route_table_id

  # ============================================================================
  # SELF-MANAGED AD (from account-111122223333)
  # Use DC01 and DC02 for US-East-2 (local DCs)
  # ============================================================================
  dc01_ip               = data.terraform_remote_state.ad_account_000000000000.outputs.dc01_private_ip
  dc02_ip               = data.terraform_remote_state.ad_account_000000000000.outputs.dc02_private_ip
  dns_ips_for_connector = [local.dc01_ip, local.dc02_ip]

  # ============================================================================
  # Common Tags
  # ============================================================================
  common_tags = merge(var.tags, {
    Project     = "org-workspaces-vdi"
    Environment = "Production"
    Region      = "us-east-2"
    Owner       = "system-architects"
    CostCenter  = "CloudArchitecture"
    ManagedBy   = "terraform"
    Compliance  = "high"
    Backup      = "daily"
    UpdatedDate = "2025-12-08"
  })
}

# ==============================================================================
# MODULE: AD CONNECTOR (US-EAST-2)
# Connects to self-managed AD domain controllers
#
# Points to:
#   - DC01 (us-east-2a) - Primary, low-latency
#   - DC02 (us-east-2b) - Secondary, failover
#
# Enables WorkSpaces in US-East-2 to authenticate against example.internal
# ==============================================================================
module "ad_connector" {
  source = "../modules/ad-connector"

  # Connector Configuration
  connector_name = "org-ad-connector-use2"
  domain_name    = var.ad_domain_name
  connector_size = "Small"

  # DNS IPs - DC01 (primary) + DC02 (failover)
  # These are the self-managed DCs from account-111122223333
  dns_ips = local.dns_ips_for_connector

  # Network Configuration
  vpc_id     = local.vpc_id
  subnet_ids = local.management_subnets

  # Service Account - must exist in example.internal AD
  # Credentials are pulled from AWS Secrets Manager (see secrets.tf)
  service_account_username = var.ad_connector_service_account
  service_account_password = local.svc_adconnector_password

  # Tags
  tags = local.common_tags
}

# ==============================================================================
# MODULE: WORKSPACES DIRECTORY
# Registers AD Connector with AWS WorkSpaces service
# ==============================================================================
module "workspaces_directory" {
  source = "../modules/workspaces-directory"

  # Directory Configuration - Use AD Connector
  directory_id = module.ad_connector.connector_id

  # Network Configuration
  vpc_id   = local.vpc_id
  vpc_cidr = local.vpc_cidr

  # Directory registration subnets (management subnets)
  directory_subnet_ids = local.management_subnets

  # WorkSpaces instance subnets (private subnets)
  subnet_ids = local.private_subnets

  # IP Access Control
  trusted_cidrs = [
    { source = "10.0.0.0/8", description = "Private RFC1918 Class A" },
    { source = "10.225.0.0/16", description = "Corporate VPN Network" },
    { source = "172.16.0.0/12", description = "Private RFC1918 Class B" },
    { source = "192.168.0.0/16", description = "Private RFC1918 Class C" },
    { source = "50.172.141.48/29", description = "Office Public IP Range" },
  ]

  # Default OU for WorkSpaces computer objects
  # This OU must exist in AD before deploying WorkSpaces
  # GPOs linked to this OU will apply to all WorkSpaces
  default_ou = "OU=WorkSpaces Computers,DC=example,DC=internal"

  # Tags
  tags = local.common_tags

  depends_on = [module.ad_connector]
}

# ==============================================================================
# MODULE: WORKSPACES
# Provisions WorkSpaces virtual desktops
# ==============================================================================
module "workspaces" {
  source = "../modules/workspaces"

  # Directory Reference
  directory_id = module.workspaces_directory.directory_id

  # WorkSpaces Configuration
  bundle_id         = var.workspaces_bundle_id
  running_mode      = var.workspaces_running_mode
  auto_stop_timeout = var.workspaces_auto_stop_timeout
  compute_type      = var.workspaces_compute_type
  root_volume_size  = var.workspaces_root_volume_size
  user_volume_size  = var.workspaces_user_volume_size

  # Users to provision WorkSpaces for
  # Users must exist in example.internal AD domain
  users = var.workspaces_users

  # Tags
  tags = local.common_tags

  depends_on = [module.workspaces_directory]
}
