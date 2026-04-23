# ==============================================================================
# OUTPUTS - US-EAST-1
# ==============================================================================

# VPC
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = var.vpc_cidr
}

# Subnets
output "public_subnet_ids" {
  value = module.subnets.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.subnets.private_subnet_ids
}

output "management_subnet_ids" {
  value = module.subnets.management_subnet_ids
}

output "inspection_subnet_ids" {
  value = module.subnets.inspection_subnet_ids
}

output "tgw_attachment_subnet_ids" {
  value = module.subnets.tgw_attachment_subnet_ids
}

# Route Tables
output "public_route_table_id" {
  value = module.subnets.public_route_table_id
}

output "private_route_table_ids" {
  value = module.subnets.private_route_table_ids
}

output "management_route_table_ids" {
  value = module.subnets.management_route_table_ids
}

output "all_route_table_ids" {
  value = concat(
    [module.subnets.public_route_table_id],
    module.subnets.private_route_table_ids,
    module.subnets.inspection_route_table_ids,
    module.subnets.tgw_route_table_ids,
    module.subnets.management_route_table_ids
  )
}

# Network Firewall
output "firewall_id" {
  value = module.network_firewall.firewall_id
}

output "firewall_arn" {
  value = module.network_firewall.firewall_arn
}

output "firewall_endpoint_ids" {
  value = module.network_firewall.firewall_endpoint_ids
}

# Transit Gateway
output "transit_gateway_id" {
  value = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_arn" {
  value = module.transit_gateway.transit_gateway_arn
}

output "transit_gateway_route_table_id" {
  value = module.transit_gateway.default_route_table_id
}

output "transit_gateway_vpc_attachment_id" {
  value = module.transit_gateway.vpc_attachment_id
}

# TGW Peering
output "tgw_peering_use2_attachment_id" {
  value = module.tgw_peering_use2.peering_attachment_id
}

output "tgw_peering_apse1_attachment_id" {
  value = module.tgw_peering_apse1.peering_attachment_id
}

# NAT Gateways
output "nat_gateway_ids" {
  value = module.subnets.nat_gateway_ids
}

output "nat_gateway_public_ips" {
  value = module.subnets.nat_gateway_public_ips
}

# Internet Gateway
output "internet_gateway_id" {
  value = module.vpc.internet_gateway_id
}
