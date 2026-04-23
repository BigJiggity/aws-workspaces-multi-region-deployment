# ==============================================================================
# ROOT MODULE: Generic WorkSpaces VDI - US-East-1
# Project: org-workspaces-vdi
# Updated: December 2025
#
# Architecture Overview:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                        US-EAST-2 (Ohio) – PRIMARY DC                        │
# │  ┌───────────────────────────────────────────────────────────────────────┐  │
# │  │         VPC 10.0.0.0/16 (account-111122223333-vpc)                       │  │
# │  │                                                                         │  │
# │  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
# │  │  │              Management Subnets                                   │  │  │
# │  │  │  ┌──────────────────────┐                                        │  │  │
# │  │  │  │  DC01 (PDC)          │                                        │  │  │
# │  │  │  │  10.0.12.10           │                                        │  │  │
# │  │  │  │  Windows 2022        │                                        │  │  │
# │  │  │  │  example.internal             │                                        │  │  │
# │  │  │  │  us-east-2a          │                                        │  │  │
# │  │  │  └──────────────────────┘                                        │  │  │
# │  │  └──────────────────────────────────────────────────────────────────┘  │  │
# │  │                                                                         │  │
# │  │  [Network Firewall] [Transit Gateway] [NAT Gateways]                   │  │
# │  └─────────────────────────────────────────────────────────────────────────┘  │
# └───────────────────────────────────────────────────────────────────────────────┘
#                                    │
#                         TGW Peering│(AD Replication & Auth)
#                                    │
# ┌───────────────────────────────────────────────────────────────────────────────┐
# │                        US-EAST-1 (N. Virginia) – WORKSPACES + DC02           │
# │  ┌─────────────────────────────────────────────────────────────────────────┐  │
# │  │           VPC 10.1.0.0/16 (org-use1-workspaces-vpc)                       │  │
# │  │                                                                           │  │
# │  │  ┌────────────────────────────────────────────────────────────────────┐  │  │
# │  │  │         Management Subnets                                          │  │  │
# │  │  │  ┌──────────────────────┐      ┌──────────────────────┐            │  │  │
# │  │  │  │  DC02 (Secondary)    │      │  AD Connector        │            │  │  │
# │  │  │  │  10.1.12.10           │      │  Points to DC02/DC01 │            │  │  │
# │  │  │  │  Windows 2022        │      │  WorkSpaces auth     │            │  │  │
# │  │  │  │  example.internal             │      │  (local DC = fast)   │            │  │  │
# │  │  │  │  us-east-1a          │      │  us-east-1b          │            │  │  │
# │  │  │  └──────────────────────┘      └──────────────────────┘            │  │  │
# │  │  └────────────────────────────────────────────────────────────────────┘  │  │
# │  │                                                                           │  │
# │  │  ┌────────────────────────────────────────────────────────────────────┐  │  │
# │  │  │     Private Subnets (WorkSpaces instances)                          │  │  │
# │  │  │     ┌────────────────────────────────────────────────────────────┐  │  │  │
# │  │  │     │         AWS WorkSpaces                                      │  │  │  │
# │  │  │     │         Domain-joined to example.internal                            │  │  │  │
# │  │  │     │         Auth via LOCAL DC02 (low latency)                   │  │  │  │
# │  │  │     └────────────────────────────────────────────────────────────┘  │  │  │
# │  │  └────────────────────────────────────────────────────────────────────┘  │  │
# │  │                                                                           │  │
# │  │  [Network Firewall] [Transit Gateway] [NAT Gateway]                      │  │
# │  └───────────────────────────────────────────────────────────────────────────┘  │
# └─────────────────────────────────────────────────────────────────────────────────┘
#
# Domain: example.internal (Self-Managed AD)
# NetBIOS: `ORG`
#
# Key Change (December 2025):
#   DC02 migrated from us-east-2b to us-east-1a for local authentication
#   AD Connector now points to DC02 (local) + DC01 (fallback via TGW)
#
# Deployment Order:
#   1. org-aws-networking/us-east-2 (VPC/Firewall/TGW - Primary DC)
#   2. org-aws-networking/us-east-1 (VPC/Firewall/TGW - WorkSpaces + DC02)
#   3. account-111122223333 (Domain Controllers DC01, DC02, DC03)
#   4. THIS PROJECT (AD Connector, WorkSpaces Directory, WorkSpaces)
#
# ==============================================================================

# ------------------------------------------------------------------------------
# DATA SOURCE: US-East-1 Networking Remote State
# ------------------------------------------------------------------------------
data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = var.networking_state_bucket
    key    = var.networking_state_key
    region = var.networking_state_region
  }
}

# ------------------------------------------------------------------------------
# DATA SOURCE: US-East-2 DC Networking Remote State
# ------------------------------------------------------------------------------
data "terraform_remote_state" "dc_networking" {
  backend = "s3"

  config = {
    bucket = var.dc_networking_state_bucket
    key    = var.dc_networking_state_key
    region = var.dc_networking_state_region
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
  # US-EAST-1 VPC (LOCAL - WorkSpaces region)
  # ============================================================================
  vpc_id                     = data.terraform_remote_state.networking.outputs.vpc_id
  vpc_cidr                   = data.terraform_remote_state.networking.outputs.vpc_cidr
  management_subnets         = data.terraform_remote_state.networking.outputs.management_subnet_ids
  private_subnets            = data.terraform_remote_state.networking.outputs.private_subnet_ids
  all_route_table_ids        = data.terraform_remote_state.networking.outputs.all_route_table_ids
  tgw_id                     = data.terraform_remote_state.networking.outputs.transit_gateway_id
  tgw_default_route_table_id = data.terraform_remote_state.networking.outputs.transit_gateway_route_table_id

  # WorkSpaces only supports certain AZs in us-east-1: use1-az2, use1-az4, use1-az6
  # Management subnets: [0]=us-east-1a (use1-az1), [1]=us-east-1b (use1-az2), [2]=us-east-1c (use1-az4)
  # Use only subnets [1] and [2] which are in supported AZs
  workspaces_subnets = slice(data.terraform_remote_state.networking.outputs.management_subnet_ids, 1, 3)

  # ============================================================================
  # US-EAST-2 VPC (DC Region)
  # ============================================================================
  dc_vpc_id   = data.terraform_remote_state.dc_networking.outputs.vpc_id
  dc_vpc_cidr = data.terraform_remote_state.dc_networking.outputs.vpc_cidr
  dc_tgw_id   = data.terraform_remote_state.dc_networking.outputs.transit_gateway_id

  # ============================================================================
  # SELF-MANAGED AD (from account-111122223333)
  # ============================================================================
  dc01_ip = data.terraform_remote_state.ad_account_000000000000.outputs.dc01_private_ip
  dc02_ip = data.terraform_remote_state.ad_account_000000000000.outputs.dc02_private_ip
  # Use us-east-1 specific output: DC02 (local) + DC01 (fallback)
  dns_ips_for_connector = data.terraform_remote_state.ad_account_000000000000.outputs.dns_ips_for_ad_connector_use1

  # ============================================================================
  # Common Tags
  # ============================================================================
  common_tags = merge(var.tags, {
    Project     = "org-workspaces-vdi"
    Environment = "Production"
    Owner       = "system-architects"
    CostCenter  = "CloudArchitecture"
    ManagedBy   = "terraform"
    Compliance  = "high"
    Backup      = "daily"
    UpdatedDate = "2025-12-12"
    Region      = "us-east-1"
  })
}

# ==============================================================================
# MODULE: AD CONNECTOR (US-EAST-1)
# Connects to self-managed AD domain controllers
#
# Points to:
#   - DC02 (us-east-1a, 10.1.12.10) - LOCAL, primary for low latency
#   - DC01 (us-east-2a, 10.0.12.10) - FALLBACK via TGW peering
#
# Enables WorkSpaces in us-east-1 to authenticate against example.internal
# Local DC provides faster authentication for WorkSpaces users
# ==============================================================================
module "ad_connector" {
  source = "../modules/ad-connector"

  # Connector Configuration
  connector_name = "org-ad-connector-use1"
  domain_name    = var.ad_domain_name
  connector_size = "Small"

  # DNS IPs - DC01 (primary) + DC02 (fallback)
  # These are the self-managed DCs from account-111122223333
  dns_ips = local.dns_ips_for_connector

  # Network Configuration - Use only subnets in WorkSpaces-supported AZs
  vpc_id     = local.vpc_id
  subnet_ids = local.workspaces_subnets

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

  # Directory registration subnets - Use only subnets in WorkSpaces-supported AZs
  directory_subnet_ids = local.workspaces_subnets

  # WorkSpaces instance subnets (private subnets in us-east-1)
  subnet_ids = local.private_subnets

  # IP Access Control - Allow all
  trusted_cidrs = [
    { source = "0.0.0.0/0", description = "Allow all" },
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

  # Disable encryption to allow imaging
  enable_encryption = false

  # Users to provision WorkSpaces for
  # Users must exist in example.internal AD domain
  users = var.workspaces_users

  # Tags
  tags = local.common_tags

  depends_on = [module.workspaces_directory]
}
