# ==============================================================================
# CLIENT VPN MODULE - VARIABLES
# ==============================================================================

# ------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ------------------------------------------------------------------------------
variable "vpc_id" {
  description = "VPC ID where Client VPN will be deployed"
  type        = string
}

variable "vpc_name" {
  description = "VPC name for tagging (per Cloud-Tagging-Standards.md)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones for VPN subnet placement"
  type        = list(string)
}

variable "vpn_subnet_cidrs" {
  description = "CIDR blocks for VPN subnets (one per AZ, must be at least /27)"
  type        = list(string)

  validation {
    condition = alltrue([
      for cidr in var.vpn_subnet_cidrs :
      tonumber(split("/", cidr)[1]) <= 27
    ])
    error_message = "VPN subnet CIDRs must be at least /27 (AWS Client VPN requirement)."
  }
}

variable "vpn_client_cidr" {
  description = "CIDR block for VPN client IP allocation (must not overlap with VPC)"
  type        = string
}

variable "firewall_endpoint_ids" {
  description = "Network Firewall endpoint IDs for routing"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets (for authorization rules)"
  type        = list(string)
}

variable "management_subnet_cidrs" {
  description = "CIDR blocks of management subnets (for authorization rules)"
  type        = list(string)
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

# ------------------------------------------------------------------------------
# OPTIONAL VARIABLES
# ------------------------------------------------------------------------------
variable "peer_vpc_cidrs" {
  description = "CIDR blocks of peer VPCs for cross-region access"
  type        = list(string)
  default     = []
}

variable "dns_servers" {
  description = "DNS servers for VPN clients (defaults to VPC DNS)"
  type        = list(string)
  default     = []
}

variable "enable_split_tunnel" {
  description = "Enable split tunnel (only VPC traffic through VPN)"
  type        = bool
  default     = true
}

variable "session_timeout_hours" {
  description = "Maximum VPN session duration in hours"
  type        = number
  default     = 24
}

variable "enable_self_service_portal" {
  description = "Enable self-service portal for client configuration download"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "certificate_validity_hours" {
  description = "Validity period for generated certificates (hours)"
  type        = number
  default     = 87600 # 10 years
}

variable "certificate_organization" {
  description = "Organization name for certificate subject"
  type        = string
  default     = "Example Corp"
}

variable "certificate_domain" {
  description = "Domain name for server certificate (e.g., example.internal or company.vpn)"
  type        = string
  default     = "vpn.internal"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "application" {
  description = "Application name for tagging (per lexicon)"
  type        = string
  default     = "client-vpn"
}

variable "criticality" {
  description = "Business criticality (Critical, High, Medium, Low)"
  type        = string
  default     = "High"

  validation {
    condition     = contains(["Critical", "High", "Medium", "Low"], var.criticality)
    error_message = "Criticality must be Critical, High, Medium, or Low."
  }
}

variable "data_class" {
  description = "Data classification (Public, Internal, Confidential, Restricted)"
  type        = string
  default     = "Internal"

  validation {
    condition     = contains(["Public", "Internal", "Confidential", "Restricted"], var.data_class)
    error_message = "DataClass must be Public, Internal, Confidential, or Restricted."
  }
}
