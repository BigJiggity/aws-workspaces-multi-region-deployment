# ==============================================================================
# MODULE: VPC-US-EAST-2
# Creates the VPC infrastructure in Ohio for AWS Managed Microsoft AD
#
# Network Architecture:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         VPC: 10.0.0.0/16                                     │
# │                                                                             │
# │  ┌─────────────────────────────────────────────────────────────────────┐   │
# │  │                      PUBLIC TIER (Internet-facing)                   │   │
# │  │  ┌─────────────────────┐        ┌─────────────────────┐             │   │
# │  │  │   public-1          │        │   public-2          │             │   │
# │  │  │   10.0.0.0/24        │        │   10.0.1.0/24        │             │   │
# │  │  │   us-east-2a        │        │   us-east-2b        │             │   │
# │  │  └─────────┬───────────┘        └──────────┬──────────┘             │   │
# │  │            │                               │                         │   │
# │  │            └───────────┬───────────────────┘                         │   │
# │  │                        │                                             │   │
# │  │                   ┌────┴────┐                                        │   │
# │  │                   │   IGW   │                                        │   │
# │  │                   └────┬────┘                                        │   │
# │  └────────────────────────┼────────────────────────────────────────────┘   │
# │                           │                                                 │
# │  ┌────────────────────────┼────────────────────────────────────────────┐   │
# │  │                  PRIVATE TIER (NAT Gateway access)                   │   │
# │  │            ┌───────────┴───────────┐                                 │   │
# │  │            │      NAT Gateway      │                                 │   │
# │  │            └───────────┬───────────┘                                 │   │
# │  │                        │                                             │   │
# │  │  ┌─────────────────────┴──┐        ┌─────────────────────┐          │   │
# │  │  │   management (private) │        │   private-2         │          │   │
# │  │  │   10.0.10.0/24          │        │   10.0.11.0/24       │          │   │
# │  │  │   us-east-2a           │        │   us-east-2b        │          │   │
# │  │  │   [Managed AD DCs]     │        │   [Managed AD DCs]  │          │   │
# │  │  └────────────────────────┘        └─────────────────────┘          │   │
# │  └─────────────────────────────────────────────────────────────────────┘   │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# Components:
#   - 1 VPC with DNS support enabled
#   - 2 Public subnets with Internet Gateway access
#   - 2 Private subnets (management tier) for Managed AD
#   - NAT Gateway for outbound internet access from private subnets
#   - Route tables for public and private traffic flows
# ==============================================================================

# ------------------------------------------------------------------------------
# INPUT VARIABLES
# ------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------

# Retrieve available AZs in us-east-2
# We need at least 2 AZs for Managed AD high availability
data "aws_availability_zones" "available" {
  state = "available"

  # Exclude Local Zones and Wavelength Zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------
locals {
  # Select the first two available AZs for deployment
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Subnet CIDR calculations
  # Public subnets: 10.0.0.0/24, 10.0.1.0/24
  # Private/Management subnets: 10.0.10.0/24, 10.0.11.0/24
  public_cidrs     = ["10.0.0.0/24", "10.0.1.0/24"]
  management_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ==============================================================================
# VPC RESOURCE
# ==============================================================================
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Enable DNS support for AD name resolution
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name        = "org-ad-vpc-us-east-2"
    Description = "VPC for AWS Managed Microsoft AD primary deployment"
    Region      = "us-east-2"
  })
}

# ==============================================================================
# INTERNET GATEWAY
# Required for public subnet internet access and NAT Gateway
# ==============================================================================
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "org-ad-igw"
  })
}

# ==============================================================================
# PUBLIC SUBNETS
# Internet-facing subnets for NAT Gateway and potential bastion hosts
# ==============================================================================
resource "aws_subnet" "public" {
  count = length(local.public_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false # Security: No auto-assign public IPs

  tags = merge(var.tags, {
    Name = "org-ad-public-${count.index + 1}-${local.azs[count.index]}"
    Tier = "public"
    AZ   = local.azs[count.index]
  })
}

# ==============================================================================
# PRIVATE/MANAGEMENT SUBNETS
# Dedicated subnets for Managed AD domain controllers
# AD requires subnets in different AZs for high availability
# ==============================================================================
resource "aws_subnet" "management" {
  count = length(local.management_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.management_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "org-ad-management-${count.index + 1}-${local.azs[count.index]}"
    Tier = "private"
    Role = "management"
    AZ   = local.azs[count.index]
  })
}

# ==============================================================================
# ELASTIC IP FOR NAT GATEWAY
# Static IP for consistent outbound traffic from private subnets
# ==============================================================================
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "org-ad-nat-eip"
  })

  # Ensure IGW exists before creating EIP
  depends_on = [aws_internet_gateway.this]
}

# ==============================================================================
# NAT GATEWAY
# Provides internet access for private subnets (AD Connect updates, etc.)
# Deployed in the first public subnet for simplicity
# ==============================================================================
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name = "org-ad-nat-gateway"
  })

  # NAT Gateway requires IGW to be attached first
  depends_on = [aws_internet_gateway.this]
}

# ==============================================================================
# ROUTE TABLES
# Separate route tables for public and private traffic flows
# ==============================================================================

# Public route table - routes to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "org-ad-public-rt"
    Tier = "public"
  })
}

# Public route to Internet Gateway
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table - routes to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "org-ad-private-rt"
    Tier = "private"
  })
}

# Private route to NAT Gateway for outbound internet access
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

# Associate management/private subnets with private route table
resource "aws_route_table_association" "management" {
  count = length(aws_subnet.management)

  subnet_id      = aws_subnet.management[count.index].id
  route_table_id = aws_route_table.private.id
}

# ==============================================================================
# VPC FLOW LOGS (Optional but recommended for compliance)
# Captures network traffic metadata for security analysis
# ==============================================================================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/org-ad-vpc-flow-logs"
  retention_in_days = 90

  tags = merge(var.tags, {
    Name = "org-ad-vpc-flow-logs"
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "org-ad-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "org-ad-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "this" {
  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn             = aws_iam_role.vpc_flow_logs.arn
  max_aggregation_interval = 60

  tags = merge(var.tags, {
    Name = "org-ad-vpc-flow-log"
  })
}
