# ==============================================================================
# US-EAST-2 NETWORKING VARIABLES
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

variable "owner" {
  description = "Resource owner for tagging (required per Cloud-Tagging-Standards.md)"
  type        = string
  default     = "platform-team"
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
  description = "CIDR blocks for private subnets"
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
  description = "CIDR blocks for management subnets (Domain Controllers)"
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

variable "use1_vpc_cidr" {
  description = "CIDR block for us-east-1 VPC"
  type        = string
}

variable "apse1_vpc_cidr" {
  description = "CIDR block for ap-southeast-1 VPC"
  type        = string
}

# ------------------------------------------------------------------------------
# TGW PEERING - US-EAST-1 (Accepter side)
# ------------------------------------------------------------------------------
variable "use1_tgw_peering_attachment_id" {
  description = "TGW peering attachment ID from us-east-1 (set after peering is created)"
  type        = string
}

variable "use1_peering_accepted" {
  description = "Set to true after TGW peering from us-east-1 is accepted"
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

# ------------------------------------------------------------------------------
# CLIENT VPN
# ------------------------------------------------------------------------------
variable "enable_client_vpn" {
  description = "Enable AWS Client VPN for remote user access"
  type        = bool
  default     = false
}

variable "vpn_subnet_cidrs" {
  description = "CIDR blocks for VPN subnets (one per AZ used)"
  type        = list(string)
  default     = []
}

variable "vpn_client_cidr" {
  description = "CIDR block for VPN client IP allocation (must not overlap with VPC)"
  type        = string
  default     = "10.100.0.0/16"
}

variable "vpn_dns_servers" {
  description = "DNS servers for VPN clients (empty = VPC DNS)"
  type        = list(string)
  default     = []
}

variable "vpn_split_tunnel" {
  description = "Enable split tunnel (only VPC traffic through VPN)"
  type        = bool
  default     = true
}

variable "vpn_session_timeout_hours" {
  description = "Maximum VPN session duration in hours"
  type        = number
  default     = 24
}

variable "vpn_certificate_organization" {
  description = "Organization name for VPN certificates"
  type        = string
  default     = "Example Corp"
}

variable "vpn_certificate_domain" {
  description = "Domain name for VPN server certificate"
  type        = string
  default     = "vpn.internal"
}
