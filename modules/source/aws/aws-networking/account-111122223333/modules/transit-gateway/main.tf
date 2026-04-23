# ==============================================================================
# SHARED MODULE: TRANSIT-GATEWAY
# Creates Transit Gateway with VPC attachment and appliance mode
# ==============================================================================

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "tgw_name" {
  description = "Name for the Transit Gateway"
  type        = string
}

variable "amazon_side_asn" {
  description = "Amazon side ASN for the Transit Gateway"
  type        = number
  default     = 64512
}

variable "enable_dns_support" {
  description = "Whether to enable DNS support"
  type        = bool
  default     = true
}

variable "enable_vpn_ecmp_support" {
  description = "Whether to enable VPN ECMP support"
  type        = bool
  default     = true
}

variable "auto_accept_shared_attachments" {
  description = "Whether to auto-accept shared attachments"
  type        = bool
  default     = true
}

variable "default_route_table_association" {
  description = "Whether to enable default route table association"
  type        = bool
  default     = true
}

variable "default_route_table_propagation" {
  description = "Whether to enable default route table propagation"
  type        = bool
  default     = true
}

variable "tgw_attachment_subnet_ids" {
  description = "Subnet IDs for TGW VPC attachment"
  type        = list(string)
}

variable "enable_appliance_mode" {
  description = "Enable appliance mode for symmetric routing"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# TRANSIT GATEWAY
# ==============================================================================
resource "aws_ec2_transit_gateway" "this" {
  description                     = var.tgw_name
  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments ? "enable" : "disable"
  default_route_table_association = var.default_route_table_association ? "enable" : "disable"
  default_route_table_propagation = var.default_route_table_propagation ? "enable" : "disable"
  dns_support                     = var.enable_dns_support ? "enable" : "disable"
  vpn_ecmp_support                = var.enable_vpn_ecmp_support ? "enable" : "disable"

  tags = merge(var.tags, {
    Name = var.tgw_name
  })
}

# ==============================================================================
# VPC ATTACHMENT
# ==============================================================================
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.vpc_id
  subnet_ids         = var.tgw_attachment_subnet_ids

  appliance_mode_support = var.enable_appliance_mode ? "enable" : "disable"

  transit_gateway_default_route_table_association = var.default_route_table_association
  transit_gateway_default_route_table_propagation = var.default_route_table_propagation

  tags = merge(var.tags, {
    Name = "${var.tgw_name}-vpc-attachment"
  })
}

# ==============================================================================
# OUTPUTS
# ==============================================================================
output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.arn
}

output "default_route_table_id" {
  description = "ID of the Transit Gateway default route table"
  value       = aws_ec2_transit_gateway.this.association_default_route_table_id
}

output "vpc_attachment_id" {
  description = "ID of the VPC attachment"
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}

output "amazon_side_asn" {
  description = "Amazon side ASN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.amazon_side_asn
}
