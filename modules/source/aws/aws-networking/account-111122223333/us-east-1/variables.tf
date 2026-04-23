# ==============================================================================
# US-EAST-1 NETWORKING VARIABLES
# Variable definitions only - values in terraform.tfvars
# ==============================================================================

# ------------------------------------------------------------------------------
# GENERAL
# ------------------------------------------------------------------------------
variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
}

# ------------------------------------------------------------------------------
# SUBNETS
# ------------------------------------------------------------------------------
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (WorkSpaces)"
  type        = list(string)
}

variable "inspection_subnet_cidrs" {
  description = "CIDR blocks for inspection subnets (Network Firewall)"
  type        = list(string)
}

variable "tgw_attachment_subnet_cidrs" {
  description = "CIDR blocks for Transit Gateway attachment subnets"
  type        = list(string)
}

variable "management_subnet_cidrs" {
  description = "CIDR blocks for management subnets (AD Connector)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway instead of one per AZ"
  type        = bool
}

# ------------------------------------------------------------------------------
# NETWORK FIREWALL
# ------------------------------------------------------------------------------
variable "firewall_name" {
  description = "Name for the Network Firewall"
  type        = string
}

variable "enable_flow_logs" {
  description = "Enable Network Firewall flow logs"
  type        = bool
}

variable "enable_alert_logs" {
  description = "Enable Network Firewall alert logs"
  type        = bool
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
}

variable "allowed_domains" {
  description = "Domains allowed through the firewall"
  type        = list(string)
}

# ------------------------------------------------------------------------------
# TRANSIT GATEWAY
# ------------------------------------------------------------------------------
variable "tgw_name" {
  description = "Name for the Transit Gateway"
  type        = string
}

variable "amazon_side_asn" {
  description = "ASN for the Transit Gateway"
  type        = number
}

variable "enable_appliance_mode" {
  description = "Enable appliance mode for TGW VPC attachment"
  type        = bool
}

# ------------------------------------------------------------------------------
# PEER VPCs
# ------------------------------------------------------------------------------
variable "peer_vpc_cidrs" {
  description = "CIDR blocks of peer VPCs for firewall rules"
  type        = list(string)
}

variable "use2_vpc_cidr" {
  description = "CIDR block for us-east-2 VPC"
  type        = string
}

variable "apse1_vpc_cidr" {
  description = "CIDR block for ap-southeast-1 VPC"
  type        = string
}

# ------------------------------------------------------------------------------
# TGW PEERING - US-EAST-2 (Requester side)
# ------------------------------------------------------------------------------
variable "use2_tgw_id" {
  description = "Transit Gateway ID in us-east-2"
  type        = string
}

variable "use2_peering_accepted" {
  description = "Set to true after TGW peering to us-east-2 is accepted"
  type        = bool
}

# ------------------------------------------------------------------------------
# TGW PEERING - AP-SOUTHEAST-1 (Requester side)
# ------------------------------------------------------------------------------
variable "apse1_tgw_id" {
  description = "Transit Gateway ID in ap-southeast-1"
  type        = string
}

variable "apse1_peering_accepted" {
  description = "Set to true after TGW peering to ap-southeast-1 is accepted"
  type        = bool
}
