# ==============================================================================
# SHARED MODULE: SUBNETS
# Creates all subnet tiers with NAT Gateways and route tables
#
# Subnet Tiers:
#   - Public: NAT Gateways, bastion hosts, ALBs
#   - Inspection: Network Firewall endpoints
#   - TGW Attachment: Transit Gateway attachments
#   - Private: WorkSpaces, application workloads
#   - Management: AD Connector, SSM endpoints
#   - VDI (optional): Local Zone subnets for WorkSpaces
# ==============================================================================

# ------------------------------------------------------------------------------
# INPUT VARIABLES
# ------------------------------------------------------------------------------
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = []
}

variable "inspection_subnet_cidrs" {
  description = "CIDR blocks for inspection subnets"
  type        = list(string)
  default     = []
}

variable "tgw_attachment_subnet_cidrs" {
  description = "CIDR blocks for TGW attachment subnets"
  type        = list(string)
  default     = []
}

variable "management_subnet_cidrs" {
  description = "CIDR blocks for management subnets"
  type        = list(string)
  default     = []
}

variable "vdi_subnet_cidrs" {
  description = "CIDR blocks for VDI subnets (Local Zone)"
  type        = list(string)
  default     = []
}

variable "vdi_azs" {
  description = "Availability zones for VDI subnets (can be Local Zones)"
  type        = list(string)
  default     = []
}

variable "create_nat_gateways" {
  description = "Whether to create NAT Gateways"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# PUBLIC SUBNETS
# ==============================================================================
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_route_table" "public" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# ==============================================================================
# NAT GATEWAYS
# ==============================================================================
locals {
  nat_gateway_count = var.create_nat_gateways && length(var.public_subnet_cidrs) > 0 ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0
}

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index % length(var.public_subnet_cidrs)].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${count.index + 1}"
  })

  depends_on = [aws_eip.nat]
}

# ==============================================================================
# INSPECTION SUBNETS
# ==============================================================================
resource "aws_subnet" "inspection" {
  count = length(var.inspection_subnet_cidrs)

  vpc_id            = var.vpc_id
  cidr_block        = var.inspection_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index % length(var.azs)]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-inspection-${count.index + 1}"
    Tier = "inspection"
  })
}

resource "aws_route_table" "inspection" {
  count = length(var.inspection_subnet_cidrs)

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-inspection-rt-${count.index + 1}"
    Tier = "inspection"
  })
}

resource "aws_route" "inspection_to_nat" {
  count = local.nat_gateway_count > 0 ? length(var.inspection_subnet_cidrs) : 0

  route_table_id         = aws_route_table.inspection[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index % local.nat_gateway_count].id
}

resource "aws_route_table_association" "inspection" {
  count = length(var.inspection_subnet_cidrs)

  subnet_id      = aws_subnet.inspection[count.index].id
  route_table_id = aws_route_table.inspection[count.index].id
}

# ==============================================================================
# TGW ATTACHMENT SUBNETS
# ==============================================================================
resource "aws_subnet" "tgw_attachment" {
  count = length(var.tgw_attachment_subnet_cidrs)

  vpc_id            = var.vpc_id
  cidr_block        = var.tgw_attachment_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index % length(var.azs)]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tgw-attach-${count.index + 1}"
    Tier = "tgw-attachment"
  })
}

resource "aws_route_table" "tgw_attachment" {
  count = length(var.tgw_attachment_subnet_cidrs)

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tgw-rt-${count.index + 1}"
    Tier = "tgw-attachment"
  })
}

resource "aws_route_table_association" "tgw_attachment" {
  count = length(var.tgw_attachment_subnet_cidrs)

  subnet_id      = aws_subnet.tgw_attachment[count.index].id
  route_table_id = aws_route_table.tgw_attachment[count.index].id
}

# ==============================================================================
# PRIVATE SUBNETS
# ==============================================================================
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = var.vpc_id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index % length(var.azs)]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-${count.index + 1}"
    Tier = "private"
  })
}

resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt-${count.index + 1}"
    Tier = "private"
  })
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ==============================================================================
# MANAGEMENT SUBNETS
# ==============================================================================
resource "aws_subnet" "management" {
  count = length(var.management_subnet_cidrs)

  vpc_id            = var.vpc_id
  cidr_block        = var.management_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index % length(var.azs)]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-management-${count.index + 1}"
    Tier = "management"
  })
}

resource "aws_route_table" "management" {
  count = length(var.management_subnet_cidrs)

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-management-rt-${count.index + 1}"
    Tier = "management"
  })
}

resource "aws_route_table_association" "management" {
  count = length(var.management_subnet_cidrs)

  subnet_id      = aws_subnet.management[count.index].id
  route_table_id = aws_route_table.management[count.index].id
}

# ==============================================================================
# VDI SUBNETS (Local Zone support)
# ==============================================================================
resource "aws_subnet" "vdi" {
  count = length(var.vdi_subnet_cidrs)

  vpc_id            = var.vpc_id
  cidr_block        = var.vdi_subnet_cidrs[count.index]
  availability_zone = length(var.vdi_azs) > 0 ? var.vdi_azs[count.index % length(var.vdi_azs)] : var.azs[count.index % length(var.azs)]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vdi-${count.index + 1}"
    Tier = "vdi"
  })
}

resource "aws_route_table" "vdi" {
  count = length(var.vdi_subnet_cidrs)

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vdi-rt-${count.index + 1}"
    Tier = "vdi"
  })
}

resource "aws_route_table_association" "vdi" {
  count = length(var.vdi_subnet_cidrs)

  subnet_id      = aws_subnet.vdi[count.index].id
  route_table_id = aws_route_table.vdi[count.index].id
}

# ==============================================================================
# OUTPUTS
# ==============================================================================
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "inspection_subnet_ids" {
  description = "IDs of the inspection subnets"
  value       = aws_subnet.inspection[*].id
}

output "tgw_attachment_subnet_ids" {
  description = "IDs of the TGW attachment subnets"
  value       = aws_subnet.tgw_attachment[*].id
}

output "management_subnet_ids" {
  description = "IDs of the management subnets"
  value       = aws_subnet.management[*].id
}

output "vdi_subnet_ids" {
  description = "IDs of the VDI subnets"
  value       = aws_subnet.vdi[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = length(aws_route_table.public) > 0 ? aws_route_table.public[0].id : null
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = aws_route_table.private[*].id
}

output "inspection_route_table_ids" {
  description = "IDs of the inspection route tables"
  value       = aws_route_table.inspection[*].id
}

output "tgw_route_table_ids" {
  description = "IDs of the TGW attachment route tables"
  value       = aws_route_table.tgw_attachment[*].id
}

output "management_route_table_ids" {
  description = "IDs of the management route tables"
  value       = aws_route_table.management[*].id
}

output "vdi_route_table_ids" {
  description = "IDs of the VDI route tables"
  value       = aws_route_table.vdi[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}
