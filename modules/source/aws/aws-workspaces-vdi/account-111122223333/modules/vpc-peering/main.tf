# ==============================================================================
# MODULE: VPC-PEERING
# Cross-region VPC peering between us-east-2 and ap-southeast-1
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

variable "requester_vpc_id" {
  description = "VPC ID of the requester"
  type        = string
}

variable "requester_vpc_cidr" {
  description = "CIDR block of the requester VPC"
  type        = string
}

variable "requester_route_table_ids" {
  description = "Route table IDs in requester VPC"
  type        = list(string)
}

variable "accepter_vpc_id" {
  description = "VPC ID of the accepter"
  type        = string
}

variable "accepter_vpc_cidr" {
  description = "CIDR block of the accepter VPC"
  type        = string
}

variable "accepter_route_table_ids" {
  description = "Route table IDs in accepter VPC"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

data "aws_region" "requester" { provider = aws.requester }
data "aws_region" "accepter" { provider = aws.accepter }
data "aws_caller_identity" "requester" { provider = aws.requester }

# VPC Peering Connection
resource "aws_vpc_peering_connection" "this" {
  provider      = aws.requester
  vpc_id        = var.requester_vpc_id
  peer_vpc_id   = var.accepter_vpc_id
  peer_region   = data.aws_region.accepter.id
  peer_owner_id = data.aws_caller_identity.requester.account_id
  auto_accept   = false

  tags = merge(var.tags, {
    Name = "org-vpc-peering-${data.aws_region.requester.id}-to-${data.aws_region.accepter.id}"
    Side = "requester"
  })
}

# Accepter
resource "aws_vpc_peering_connection_accepter" "this" {
  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  auto_accept               = true

  tags = merge(var.tags, {
    Name = "org-vpc-peering-${data.aws_region.requester.id}-to-${data.aws_region.accepter.id}"
    Side = "accepter"
  })
}

# DNS Resolution options
resource "aws_vpc_peering_connection_options" "requester" {
  provider                  = aws.requester
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  requester { allow_remote_vpc_dns_resolution = true }
  depends_on = [aws_vpc_peering_connection_accepter.this]
}

resource "aws_vpc_peering_connection_options" "accepter" {
  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  accepter { allow_remote_vpc_dns_resolution = true }
  depends_on = [aws_vpc_peering_connection_accepter.this]
}

# Routes: Requester → Accepter
resource "aws_route" "requester_to_accepter" {
  provider                  = aws.requester
  count                     = length(var.requester_route_table_ids)
  route_table_id            = var.requester_route_table_ids[count.index]
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  depends_on                = [aws_vpc_peering_connection_accepter.this]
}

# Routes: Accepter → Requester
resource "aws_route" "accepter_to_requester" {
  provider                  = aws.accepter
  count                     = length(var.accepter_route_table_ids)
  route_table_id            = var.accepter_route_table_ids[count.index]
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  depends_on                = [aws_vpc_peering_connection_accepter.this]
}
