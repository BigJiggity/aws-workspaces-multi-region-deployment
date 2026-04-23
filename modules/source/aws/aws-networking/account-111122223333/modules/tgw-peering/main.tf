# ==============================================================================
# SHARED MODULE: TGW-PEERING
# Creates Transit Gateway peering attachment to another region/account
# ==============================================================================

variable "enabled" {
  description = "Whether to create the peering attachment"
  type        = bool
  default     = true
}

variable "transit_gateway_id" {
  description = "ID of the local Transit Gateway"
  type        = string
}

variable "peer_transit_gateway_id" {
  description = "ID of the peer Transit Gateway"
  type        = string
}

variable "peer_region" {
  description = "Region of the peer Transit Gateway"
  type        = string
}

variable "peer_account_id" {
  description = "Account ID of the peer Transit Gateway"
  type        = string
}

variable "tgw_route_table_id" {
  description = "Route table ID for the local Transit Gateway"
  type        = string
}

variable "peer_vpc_cidr" {
  description = "CIDR block of the peer VPC"
  type        = string
}

variable "peering_name" {
  description = "Name for the peering attachment"
  type        = string
  default     = "tgw-peering"
}

variable "create_route" {
  description = "Create route after peering is accepted"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# TGW PEERING ATTACHMENT
# ==============================================================================
resource "aws_ec2_transit_gateway_peering_attachment" "this" {
  count = var.enabled ? 1 : 0

  transit_gateway_id      = var.transit_gateway_id
  peer_transit_gateway_id = var.peer_transit_gateway_id
  peer_region             = var.peer_region
  peer_account_id         = var.peer_account_id

  tags = merge(var.tags, {
    Name = var.peering_name
    Side = "requester"
  })
}

# ==============================================================================
# ROUTE TO PEER VPC
# Only created when create_route = true (after peering accepted)
# ==============================================================================
resource "aws_ec2_transit_gateway_route" "to_peer" {
  count = var.enabled && var.create_route ? 1 : 0

  destination_cidr_block         = var.peer_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this[0].id
  transit_gateway_route_table_id = var.tgw_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment.this]
}

# ==============================================================================
# OUTPUTS
# ==============================================================================
output "peering_attachment_id" {
  description = "ID of the peering attachment"
  value       = var.enabled ? aws_ec2_transit_gateway_peering_attachment.this[0].id : null
}

output "peering_attachment_state" {
  description = "State of the peering attachment"
  value       = var.enabled ? "requested" : null
}
