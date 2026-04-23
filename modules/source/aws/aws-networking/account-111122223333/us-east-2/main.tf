# ==============================================================================
# US-EAST-2 NETWORKING DEPLOYMENT
# Region: us-east-2 (Ohio)
# VPC CIDR: 10.0.0.0/16
#
# Purpose: Primary DC region (DC01, DC02), management infrastructure
#
# Resources Deployed:
#   - VPC with Internet Gateway
#   - Public subnets (NAT Gateways)
#   - Private subnets (workloads)
#   - Management subnets (DCs, AD Connector)
#   - Inspection subnets (Network Firewall)
#   - TGW attachment subnets
#   - AWS Network Firewall
#   - Transit Gateway
#
# Cross-Region Connectivity:
#   - TGW Peering FROM us-east-1 (10.4.0.0/16) - WorkSpaces (accepter)
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
    key            = "networking/us-east-2/terraform.tfstate"
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
# Following Cloud-Tagging-Standards.md Section 5.1 Inheritance Model
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
  vpn_client_cidrs        = var.enable_client_vpn ? [var.vpn_client_cidr] : []
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
# TGW PEERING ACCEPTER - US-EAST-1
# Accepts peering initiated from us-east-1
# Only creates accepter if peering exists but NOT yet accepted
# ==============================================================================
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "use1" {
  count = var.use1_tgw_peering_attachment_id != "" && !var.use1_peering_accepted ? 1 : 0

  transit_gateway_attachment_id = var.use1_tgw_peering_attachment_id

  tags = merge(local.common_tags, {
    Name = "use2-accept-use1"
    Side = "accepter"
  })
}

# Route to us-east-1 via accepted peering
resource "aws_ec2_transit_gateway_route" "to_use1" {
  count = var.use1_tgw_peering_attachment_id != "" && var.use1_peering_accepted ? 1 : 0

  destination_cidr_block         = var.use1_vpc_cidr
  transit_gateway_attachment_id  = var.use1_tgw_peering_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.default_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.use1]
}

# ==============================================================================
# TGW PEERING - AP-SOUTHEAST-1
# Initiates peering to ap-southeast-1
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
  peering_name            = "use2-to-apse1"
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

# Public RT → us-east-1 via firewall
resource "aws_route" "public_to_use1" {
  route_table_id         = module.subnets.public_route_table_id
  destination_cidr_block = var.use1_vpc_cidr
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[0]

  depends_on = [module.network_firewall]
}

# Inspection → us-east-1 via TGW
resource "aws_route" "inspection_to_use1" {
  count = length(var.inspection_subnet_cidrs)

  route_table_id         = module.subnets.inspection_route_table_ids[count.index]
  destination_cidr_block = var.use1_vpc_cidr
  transit_gateway_id     = module.transit_gateway.transit_gateway_id

  depends_on = [module.transit_gateway]
}

# Public RT → ap-southeast-1 via firewall
resource "aws_route" "public_to_apse1" {
  route_table_id         = module.subnets.public_route_table_id
  destination_cidr_block = var.apse1_vpc_cidr
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[0]

  depends_on = [module.network_firewall]
}

# Inspection → ap-southeast-1 via TGW
resource "aws_route" "inspection_to_apse1" {
  count = length(var.inspection_subnet_cidrs)

  route_table_id         = module.subnets.inspection_route_table_ids[count.index]
  destination_cidr_block = var.apse1_vpc_cidr
  transit_gateway_id     = module.transit_gateway.transit_gateway_id

  depends_on = [module.transit_gateway]
}

# ==============================================================================
# CLIENT VPN
# Allows remote users to connect securely to private resources
# Traffic flows through Network Firewall for inspection
# ==============================================================================
module "client_vpn" {
  source = "../modules/client-vpn"

  count = var.enable_client_vpn ? 1 : 0

  vpc_id                   = module.vpc.vpc_id
  vpc_name                 = var.vpc_name
  vpc_cidr                 = var.vpc_cidr
  azs                      = slice(var.azs, 0, 2) # Use first 2 AZs for VPN
  vpn_subnet_cidrs         = var.vpn_subnet_cidrs
  vpn_client_cidr          = var.vpn_client_cidr
  firewall_endpoint_ids    = module.network_firewall.firewall_endpoint_ids
  private_subnet_cidrs     = var.private_subnet_cidrs
  management_subnet_cidrs  = var.management_subnet_cidrs
  peer_vpc_cidrs           = var.peer_vpc_cidrs
  name_prefix              = var.name_prefix
  dns_servers              = var.vpn_dns_servers
  enable_split_tunnel      = var.vpn_split_tunnel
  session_timeout_hours    = var.vpn_session_timeout_hours
  log_retention_days       = var.log_retention_days
  certificate_organization = var.vpn_certificate_organization
  certificate_domain       = var.vpn_certificate_domain

  # Tagging per Cloud-Tagging-Standards.md
  application = "client-vpn"
  criticality = "High"
  data_class  = "Internal"
  tags        = local.common_tags

  depends_on = [module.network_firewall, module.subnets]
}

# ==============================================================================
# VPN RETURN TRAFFIC ROUTES
# Route return traffic from public subnets to VPN clients through firewall
# ==============================================================================
resource "aws_route" "public_to_vpn_clients" {
  count = var.enable_client_vpn ? 1 : 0

  route_table_id         = module.subnets.public_route_table_id
  destination_cidr_block = var.vpn_client_cidr
  vpc_endpoint_id        = module.network_firewall.firewall_endpoint_ids[0]

  depends_on = [module.network_firewall]
}

# Route from inspection subnets to VPN client CIDR
resource "aws_route" "inspection_to_vpn_clients" {
  count = var.enable_client_vpn ? length(var.inspection_subnet_cidrs) : 0

  route_table_id         = module.subnets.inspection_route_table_ids[count.index]
  destination_cidr_block = var.vpn_client_cidr
  nat_gateway_id         = module.subnets.nat_gateway_ids[0]

  depends_on = [module.subnets]
}
