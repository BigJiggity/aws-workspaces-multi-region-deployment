# ==============================================================================
# MODULE: TRANSIT-GATEWAY-PEERING
# Cross-region Transit Gateway peering for inspected inter-region connectivity
#
# Architecture:
#   US-East-2 VPC → TGW (us-east-2) → Network Firewall → TGW Peering →
#   → TGW (ap-southeast-1) → Network Firewall → Landing Zone VPC
#
# All cross-region traffic flows through Network Firewalls in both regions
# for centralized inspection, logging, and security policy enforcement.
# ==============================================================================

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.40"
      configuration_aliases = [aws.requester, aws.accepter]
    }
  }
}

# ------------------------------------------------------------------------------
# VARIABLES
# ------------------------------------------------------------------------------
variable "requester_tgw_id" {
  description = "Transit Gateway ID in the requester region (us-east-2)"
  type        = string
}

variable "requester_tgw_route_table_id" {
  description = "Transit Gateway default route table ID in requester region"
  type        = string
}

variable "requester_region" {
  description = "AWS region for requester Transit Gateway"
  type        = string
}

variable "requester_cidr" {
  description = "CIDR block to advertise from requester (us-east-2 VPC)"
  type        = string
}

variable "accepter_tgw_id" {
  description = "Transit Gateway ID in the accepter region (ap-southeast-1)"
  type        = string
}

variable "accepter_tgw_route_table_id" {
  description = "Transit Gateway default route table ID in accepter region"
  type        = string
}

variable "accepter_region" {
  description = "AWS region for accepter Transit Gateway"
  type        = string
}

variable "accepter_cidr" {
  description = "CIDR block to advertise from accepter (Manila Landing Zone VPC)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------
data "aws_caller_identity" "requester" {
  provider = aws.requester
}

# ------------------------------------------------------------------------------
# TRANSIT GATEWAY PEERING ATTACHMENT
# Creates peering connection between Transit Gateways in different regions
#
# This allows the two Transit Gateways to exchange routes and forward traffic
# between regions. All traffic will still flow through Network Firewalls due
# to TGW appliance mode configuration.
# ------------------------------------------------------------------------------
resource "aws_ec2_transit_gateway_peering_attachment" "this" {
  provider = aws.requester

  transit_gateway_id      = var.requester_tgw_id
  peer_transit_gateway_id = var.accepter_tgw_id
  peer_region             = var.accepter_region
  peer_account_id         = data.aws_caller_identity.requester.account_id

  tags = merge(var.tags, {
    Name = "org-tgw-peering-${var.requester_region}-to-${var.accepter_region}"
    Side = "requester"
  })
}

# ------------------------------------------------------------------------------
# ACCEPT PEERING ATTACHMENT
# Accepter side must explicitly accept the peering request
#
# After acceptance, both Transit Gateways can exchange routes.
# ------------------------------------------------------------------------------
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "this" {
  provider = aws.accepter

  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.this.id

  tags = merge(var.tags, {
    Name = "org-tgw-peering-${var.requester_region}-to-${var.accepter_region}"
    Side = "accepter"
  })
}

# ------------------------------------------------------------------------------
# WAIT FOR PEERING TO BE AVAILABLE
# TGW peering attachment takes time to establish (typically 1-2 minutes)
# ------------------------------------------------------------------------------
resource "time_sleep" "wait_for_peering" {
  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.this]

  # TGW peering can take 2-5 minutes to become fully available
  create_duration = "5m"
}

# ------------------------------------------------------------------------------
# REQUESTER SIDE: ROUTE TO ACCEPTER CIDR
# Routes traffic destined for Landing Zone (10.2.0.0/16) through TGW peering
#
# Traffic flow: us-east-2 VPC → TGW → Network Firewall → TGW peering →
#               ap-southeast-1 TGW → Network Firewall → Landing Zone
# ------------------------------------------------------------------------------
resource "aws_ec2_transit_gateway_route" "requester_to_accepter" {
  provider = aws.requester

  destination_cidr_block         = var.accepter_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = var.requester_tgw_route_table_id

  depends_on = [time_sleep.wait_for_peering]
}

# ------------------------------------------------------------------------------
# ACCEPTER SIDE: ROUTE TO REQUESTER CIDR
# Routes traffic destined for US-East-2 VPC (10.0.0.0/16) through TGW peering
#
# Traffic flow: Landing Zone → TGW → Network Firewall → TGW peering →
#               us-east-2 TGW → Network Firewall → us-east-2 VPC
# ------------------------------------------------------------------------------
resource "aws_ec2_transit_gateway_route" "accepter_to_requester" {
  provider = aws.accepter

  destination_cidr_block         = var.requester_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = var.accepter_tgw_route_table_id

  depends_on = [time_sleep.wait_for_peering]
}
