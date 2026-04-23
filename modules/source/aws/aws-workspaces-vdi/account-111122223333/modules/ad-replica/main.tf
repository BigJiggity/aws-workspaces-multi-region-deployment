# ==============================================================================
# MODULE: AD-REPLICA
# Deploys AWS Managed AD replica in ap-southeast-1 for low-latency WorkSpaces auth
# ==============================================================================

variable "directory_id" {
  description = "ID of the primary Managed AD directory"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID in the replica region (ap-southeast-1 Landing Zone)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for replica domain controllers (management subnets)"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR for security group rules (Landing Zone: 10.2.0.0/16)"
  type        = string
}

variable "ad_vpc_cidr" {
  description = "Primary AD VPC CIDR for replication traffic (US-East-2: 10.0.0.0/16)"
  type        = string
}

variable "workspaces_cidr" {
  description = "CIDR block for WorkSpaces subnets (Manila Local Zone VDI subnets)"
  type        = string
  default     = ""
}

variable "desired_dc_count" {
  description = "Number of domain controllers in replica region"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------
# Get the replica region from the replica provider
data "aws_region" "current" {
  provider = aws.replica
}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------
locals {
  # Use workspaces_cidr if provided, otherwise use vpc_cidr (assumes WorkSpaces in same VPC)
  workspaces_cidr = var.workspaces_cidr != "" ? var.workspaces_cidr : var.vpc_cidr

  # Combined CIDRs that need access to AD Replica:
  #   1. Local VPC (10.2.0.0/16) - for local services
  #   2. Primary AD VPC (10.0.0.0/16) - for AD replication traffic
  #   3. WorkSpaces subnets - for authentication traffic from Manila Local Zone
  allowed_cidrs = distinct([var.vpc_cidr, var.ad_vpc_cidr, local.workspaces_cidr])
}

# ------------------------------------------------------------------------------
# SECURITY GROUP: AD REPLICA
# Allows AD traffic from local VPC, primary AD, and WorkSpaces
# ------------------------------------------------------------------------------
resource "aws_security_group" "ad_replica" {
  provider = aws.replica

  name        = "org-ad-replica-sg"
  description = "Security group for AD replica domain controllers - allows all AD protocols"
  vpc_id      = var.vpc_id

  # ============================================================================
  # INBOUND RULES - Active Directory Protocols
  # These rules allow AD traffic from:
  #   1. Local VPC (10.2.0.0/16) - for local services
  #   2. Primary AD VPC (10.0.0.0/16) - for AD replication
  #   3. WorkSpaces VDI subnets - for authentication (critical for Manila users)
  # ============================================================================

  # DNS - Domain Name System (TCP and UDP)
  dynamic "ingress" {
    for_each = [
      { port = 53, proto = "tcp", desc = "DNS TCP from allowed networks" },
      { port = 53, proto = "udp", desc = "DNS UDP from allowed networks" },
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.proto
      cidr_blocks = local.allowed_cidrs
    }
  }

  # Kerberos - Primary authentication protocol (critical for WorkSpaces login)
  dynamic "ingress" {
    for_each = [
      { port = 88, proto = "tcp", desc = "Kerberos TCP from allowed networks" },
      { port = 88, proto = "udp", desc = "Kerberos UDP from allowed networks" },
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.proto
      cidr_blocks = local.allowed_cidrs
    }
  }

  # NTP - Network Time Protocol (critical for Kerberos time synchronization)
  ingress {
    description = "NTP from allowed networks"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = local.allowed_cidrs
  }

  # RPC Endpoint Mapper
  ingress {
    description = "RPC Endpoint Mapper from allowed networks"
    from_port   = 135
    to_port     = 135
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  # LDAP - Lightweight Directory Access Protocol (used by WorkSpaces for auth)
  dynamic "ingress" {
    for_each = [
      { port = 389, proto = "tcp", desc = "LDAP TCP from allowed networks" },
      { port = 389, proto = "udp", desc = "LDAP UDP from allowed networks" },
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.proto
      cidr_blocks = local.allowed_cidrs
    }
  }

  # SMB - Server Message Block (Group Policy and file sharing)
  ingress {
    description = "SMB from allowed networks"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  # Kerberos Password Change
  dynamic "ingress" {
    for_each = [
      { port = 464, proto = "tcp", desc = "Kerberos Password Change TCP" },
      { port = 464, proto = "udp", desc = "Kerberos Password Change UDP" },
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.proto
      cidr_blocks = local.allowed_cidrs
    }
  }

  # LDAPS - LDAP over TLS
  ingress {
    description = "LDAPS from allowed networks"
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  # Global Catalog - Forest-wide directory searches
  ingress {
    description = "Global Catalog (LDAP) from allowed networks"
    from_port   = 3268
    to_port     = 3268
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    description = "Global Catalog (LDAPS) from allowed networks"
    from_port   = 3269
    to_port     = 3269
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  # RPC Dynamic Ports - Used by various AD services and replication
  ingress {
    description = "RPC Dynamic Ports from allowed networks"
    from_port   = 49152
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  # ============================================================================
  # OUTBOUND RULES - Allow all outbound
  # ============================================================================
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name        = "org-ad-replica-sg"
    Description = "AD Replica security group with full protocol support for WorkSpaces"
  })
}

# ------------------------------------------------------------------------------
# AD REPLICA REGION
# Deploys AD domain controllers in ap-southeast-1
# NOTE: This API call must go to the PRIMARY region's Directory Service
# ------------------------------------------------------------------------------
resource "aws_directory_service_region" "replica" {
  provider = aws.primary # MUST use primary region provider!

  directory_id = var.directory_id
  region_name  = data.aws_region.current.id # Replica region from data source

  vpc_settings {
    vpc_id     = var.vpc_id
    subnet_ids = length(var.subnet_ids) >= 2 ? slice(var.subnet_ids, 0, 2) : var.subnet_ids
  }

  desired_number_of_domain_controllers = var.desired_dc_count

  tags = merge(var.tags, {
    Name        = "org-ad-replica-${data.aws_region.current.id}"
    Description = "AD Replica for low-latency WorkSpaces authentication"
  })
}

# ------------------------------------------------------------------------------
# WAIT FOR REPLICA DEPLOYMENT AND REPLICATION
# AD replica deployment and full replication sync takes 30-45 minutes:
#   - Initial replica creation: ~10 minutes
#   - AD replication sync: ~20-30 minutes
#   - DNS propagation: ~5 minutes
# We wait 45 minutes to ensure full synchronization before WorkSpaces deployment
# ------------------------------------------------------------------------------
resource "time_sleep" "wait_for_replica" {
  depends_on = [aws_directory_service_region.replica]

  # AD replica deployment and full replication sync takes 30-45 minutes:
  #   - Initial replica creation: ~10-15 minutes
  #   - AD replication sync: ~15-25 minutes  
  #   - DNS propagation and regional availability: ~5-10 minutes
  # WorkSpaces registration will fail if directory isn't visible in region yet
  create_duration = "45m"
}

# ------------------------------------------------------------------------------
# DATA SOURCE: REPLICA DIRECTORY INFO
# Retrieves DNS IPs and other info after replica is deployed
# IMPORTANT: Must use replica provider to get replica's DNS IPs, not primary's
# ------------------------------------------------------------------------------
data "aws_directory_service_directory" "replica" {
  provider = aws.replica # Query from replica region to get replica DNS IPs

  directory_id = var.directory_id

  depends_on = [time_sleep.wait_for_replica]
}
