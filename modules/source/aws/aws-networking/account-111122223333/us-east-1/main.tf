# ==============================================================================
# US-EAST-1 NETWORKING DEPLOYMENT
# Region: us-east-1 (N. Virginia)
# VPC CIDR: 10.4.0.0/16
#
# Purpose: WorkSpaces VDI region (WorkSpaces not available in us-east-2)
#
# Resources Deployed:
#   - VPC with Internet Gateway
#   - Public subnets (NAT Gateways)
#   - Private subnets (WorkSpaces)
#   - Management subnets (AD Connector)
#   - Inspection subnets (Network Firewall)
#   - TGW attachment subnets
#   - AWS Network Firewall
#   - Transit Gateway
#   - TGW Peering to us-east-2 and ap-southeast-1
#
# Cross-Region Connectivity:
#   - TGW Peering TO us-east-2 (10.0.0.0/16) - DC01, DC02 (requester)
#   - TGW Peering TO ap-southeast-1 (10.2.0.0/16) - DC03, Manila WorkSpaces (requester)
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }

  backend "s3" {
    bucket         = "org-terraform-state-account-111122223333-111122223333"
    key            = "networking/us-east-1/terraform.tfstate"
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
      Region      = var.region
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# LOCAL VALUES (Computed/Derived only)
# ------------------------------------------------------------------------------
locals {
  common_tags = {
    VPC    = var.vpc_name
    Region = var.region
  }
}

# ==============================================================================
# VPC
# ==============================================================================
module "vpc" {
  source = "../modules/vpc"

  vpc_cidr = var.vpc_cidr
  vpc_name = var.vpc_name
  tags     = local.common_tags
}

# ==============================================================================
# SUBNETS
# ==============================================================================
module "subnets" {
  source = "../modules/subnets"

  vpc_id                      = module.vpc.vpc_id
  internet_gateway_id         = module.vpc.internet_gateway_id
  azs                         = var.azs
  name_prefix                 = var.name_prefix
  public_subnet_cidrs         = var.public_subnet_cidrs
  private_subnet_cidrs        = var.private_subnet_cidrs
  inspection_subnet_cidrs     = var.inspection_subnet_cidrs
  tgw_attachment_subnet_cidrs = var.tgw_attachment_subnet_cidrs
  management_subnet_cidrs     = var.management_subnet_cidrs
  single_nat_gateway          = var.single_nat_gateway
  tags                        = local.common_tags

  depends_on = [module.vpc]
}

# ==============================================================================
# NETWORK FIREWALL
# ==============================================================================
module "network_firewall" {
  source = "../modules/network-firewall"

  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = var.vpc_cidr
  firewall_name           = var.firewall_name
  inspection_subnet_ids   = module.subnets.inspection_subnet_ids
  private_subnet_cidrs    = var.private_subnet_cidrs
  management_subnet_cidrs = var.management_subnet_cidrs
  peer_vpc_cidrs          = var.peer_vpc_cidrs
  allowed_domains         = var.allowed_domains
  enable_flow_logs        = var.enable_flow_logs
  enable_alert_logs       = var.enable_alert_logs
  log_retention_days      = var.log_retention_days
  tags                    = local.common_tags

  depends_on = [module.subnets]
}

# ==============================================================================
# TRANSIT GATEWAY
# ==============================================================================
module "transit_gateway" {
  source = "../modules/transit-gateway"

  vpc_id                    = module.vpc.vpc_id
  tgw_name                  = var.tgw_name
  amazon_side_asn           = var.amazon_side_asn
  tgw_attachment_subnet_ids = module.subnets.tgw_attachment_subnet_ids
  enable_appliance_mode     = var.enable_appliance_mode
  tags                      = local.common_tags

  depends_on = [module.subnets]
}

# ==============================================================================
# TGW PEERING - US-EAST-2 (Requester side)
# us-east-1 initiates peering TO us-east-2
# ==============================================================================
module "tgw_peering_use2" {
  source = "../modules/tgw-peering"

  enabled                 = var.use2_tgw_id != ""
  transit_gateway_id      = module.transit_gateway.transit_gateway_id
  peer_transit_gateway_id = var.use2_tgw_id
  peer_region             = "us-east-2"
  peer_account_id         = data.aws_caller_identity.current.account_id
  tgw_route_table_id      = module.transit_gateway.default_route_table_id
  peer_vpc_cidr           = var.use2_vpc_cidr
  peering_name            = "use1-to-use2"
  create_route            = var.use2_peering_accepted
  tags                    = local.common_tags

  depends_on = [module.transit_gateway]
}

# ==============================================================================
# TGW PEERING - AP-SOUTHEAST-1 (Requester side)
# us-east-1 initiates peering TO ap-southeast-1
# ==============================================================================
module "tgw_peering_apse1" {
  source = "../modules/tgw-peering"

  enabled                 = var.apse1_tgw_id != ""
  transit_gateway_id      = module.transit_gateway.transit_gateway_id
  peer_transit_gateway_id = var.apse1_tgw_id
  peer_region             = "ap-southeast-1"
  peer_account_id         = data.aws_caller_identity.current.account_id
  tgw_route_table_id      = module.transit_gateway.default_route_table_id
  peer_vpc_cidr           = var.apse1_vpc_cidr
  peering_name            = "use1-to-apse1"
  create_route            = var.apse1_peering_accepted
  tags                    = local.common_tags

  depends_on = [module.transit_gateway]
}

# ==============================================================================
# ROUTE TABLE UPDATES - FIREWALL INTEGRATION
# ==============================================================================

# Private subnets → Firewall
resource "aws_route" "private_to_firewall" {
  count = length(var.private_subnet_cidrs)

  route_table_id         = module.subnets.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[count.index % length(var.inspection_subnet_cidrs)]

  depends_on = [module.network_firewall]
}

# Management subnets → Firewall
resource "aws_route" "management_to_firewall" {
  count = length(var.management_subnet_cidrs)

  route_table_id         = module.subnets.management_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[count.index % length(var.inspection_subnet_cidrs)]

  depends_on = [module.network_firewall]
}

# TGW subnets → Firewall (default route)
resource "aws_route" "tgw_to_firewall" {
  count = length(var.tgw_attachment_subnet_cidrs)

  route_table_id         = module.subnets.tgw_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[count.index % length(var.inspection_subnet_cidrs)]

  depends_on = [module.network_firewall]
}

# TGW RT → Firewall (incoming cross-region traffic to management subnets)
resource "aws_route" "tgw_to_firewall_management" {
  count = length(var.tgw_attachment_subnet_cidrs) * length(var.management_subnet_cidrs)

  route_table_id         = module.subnets.tgw_route_table_ids[floor(count.index / length(var.management_subnet_cidrs))]
  destination_cidr_block = var.management_subnet_cidrs[count.index % length(var.management_subnet_cidrs)]
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[floor(count.index / length(var.management_subnet_cidrs)) % length(var.inspection_subnet_cidrs)]

  depends_on = [module.network_firewall]
}

# TGW RT → Firewall (incoming cross-region traffic to private subnets)
resource "aws_route" "tgw_to_firewall_private" {
  count = length(var.tgw_attachment_subnet_cidrs) * length(var.private_subnet_cidrs)

  route_table_id         = module.subnets.tgw_route_table_ids[floor(count.index / length(var.private_subnet_cidrs))]
  destination_cidr_block = var.private_subnet_cidrs[count.index % length(var.private_subnet_cidrs)]
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[floor(count.index / length(var.private_subnet_cidrs)) % length(var.inspection_subnet_cidrs)]

  depends_on = [module.network_firewall]
}

# Public RT → Firewall (return traffic for private subnets)
resource "aws_route" "public_to_firewall_private" {
  count = length(var.private_subnet_cidrs)

  route_table_id         = module.subnets.public_route_table_id
  destination_cidr_block = var.private_subnet_cidrs[count.index]
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[count.index % length(var.inspection_subnet_cidrs)]

  depends_on = [module.network_firewall]
}

# Public RT → Firewall (return traffic for management subnets)
resource "aws_route" "public_to_firewall_management" {
  count = length(var.management_subnet_cidrs)

  route_table_id         = module.subnets.public_route_table_id
  destination_cidr_block = var.management_subnet_cidrs[count.index]
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[count.index % length(var.inspection_subnet_cidrs)]

  depends_on = [module.network_firewall]
}

# ==============================================================================
# CROSS-REGION ROUTES VIA FIREWALL
# ==============================================================================

# Public RT → us-east-2 via firewall
resource "aws_route" "public_to_use2" {
  count = var.use2_tgw_id != "" ? 1 : 0

  route_table_id         = module.subnets.public_route_table_id
  destination_cidr_block = var.use2_vpc_cidr
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[0]

  depends_on = [module.network_firewall]
}

# Inspection → us-east-2 via TGW
resource "aws_route" "inspection_to_use2" {
  count = var.use2_tgw_id != "" ? length(var.inspection_subnet_cidrs) : 0

  route_table_id         = module.subnets.inspection_route_table_ids[count.index]
  destination_cidr_block = var.use2_vpc_cidr
  transit_gateway_id     = module.transit_gateway.transit_gateway_id

  depends_on = [module.transit_gateway]
}

# Public RT → ap-southeast-1 via firewall
resource "aws_route" "public_to_apse1" {
  count = var.apse1_tgw_id != "" ? 1 : 0

  route_table_id         = module.subnets.public_route_table_id
  destination_cidr_block = var.apse1_vpc_cidr
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[0]

  depends_on = [module.network_firewall]
}

# Inspection → ap-southeast-1 via TGW
resource "aws_route" "inspection_to_apse1" {
  count = var.apse1_tgw_id != "" ? length(var.inspection_subnet_cidrs) : 0

  route_table_id         = module.subnets.inspection_route_table_ids[count.index]
  destination_cidr_block = var.apse1_vpc_cidr
  transit_gateway_id     = module.transit_gateway.transit_gateway_id

  depends_on = [module.transit_gateway]
}
