# ==============================================================================
# MODULE: WORKSPACES-DIRECTORY
# Registers Managed AD with AWS WorkSpaces service
# ==============================================================================

variable "directory_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "directory_subnet_ids" {
  description = "Subnet IDs for WorkSpaces directory registration (must be in same AZs as AD domain controllers, NOT Local Zones)"
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "Subnet IDs for WorkSpaces instances (can be in Local Zones)"
  type        = list(string)
}

variable "vpc_cidr" {
  type = string
}

variable "enable_internet_access" {
  type    = bool
  default = false
}

variable "enable_maintenance_mode" {
  type    = bool
  default = true
}

variable "default_ou" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

# ------------------------------------------------------------------------------
# SECURITY GROUP: WORKSPACES
# Allows client connectivity (PCoIP/WSP) and AD authentication traffic
# ------------------------------------------------------------------------------
resource "aws_security_group" "workspaces" {
  name        = "org-workspaces-sg"
  description = "Security group for WorkSpaces instances"
  vpc_id      = var.vpc_id

  # ============================================================================
  # INBOUND RULES - Client Access (PCoIP and WSP streaming protocols)
  # ============================================================================

  # PCoIP Protocol (legacy protocol, UDP 4172 for data, TCP 4172 for control)
  ingress {
    description = "PCoIP TCP (control channel)"
    from_port   = 4172
    to_port     = 4172
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "PCoIP UDP (data channel)"
    from_port   = 4172
    to_port     = 4172
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # WSP Protocol (WorkSpaces Streaming Protocol - newer, more efficient)
  ingress {
    description = "WSP TCP (control channel)"
    from_port   = 4195
    to_port     = 4195
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "WSP UDP (data channel)"
    from_port   = 4195
    to_port     = 4195
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS for WorkSpaces management and API calls
  ingress {
    description = "HTTPS for WorkSpaces management"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ============================================================================
  # INBOUND RULES - Active Directory Authentication
  # WorkSpaces need to receive responses from AD for authentication
  # ============================================================================

  # DNS (Domain Name System) - Required for AD domain resolution
  ingress {
    description = "DNS TCP from VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "DNS UDP from VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Kerberos - Primary authentication protocol for AD
  ingress {
    description = "Kerberos TCP from VPC"
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Kerberos UDP from VPC"
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # LDAP - Directory queries and Group Policy
  ingress {
    description = "LDAP TCP from VPC"
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "LDAP UDP from VPC"
    from_port   = 389
    to_port     = 389
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # LDAPS - Secure LDAP
  ingress {
    description = "LDAPS from VPC"
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SMB - File sharing and Group Policy files
  ingress {
    description = "SMB from VPC"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # RPC - Remote Procedure Calls for AD operations
  ingress {
    description = "RPC Endpoint Mapper from VPC"
    from_port   = 135
    to_port     = 135
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # RPC Dynamic Ports - Used by various AD services
  ingress {
    description = "RPC Dynamic Ports from VPC"
    from_port   = 49152
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Global Catalog - For forest-wide searches
  ingress {
    description = "Global Catalog from VPC"
    from_port   = 3268
    to_port     = 3269
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Kerberos Password Change
  ingress {
    description = "Kerberos Password Change TCP from VPC"
    from_port   = 464
    to_port     = 464
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Kerberos Password Change UDP from VPC"
    from_port   = 464
    to_port     = 464
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # NTP - Time synchronization (critical for Kerberos)
  ingress {
    description = "NTP from VPC"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ============================================================================
  # OUTBOUND RULES - Allow all outbound traffic
  # WorkSpaces need to reach AD, AWS services, and the Internet
  # ============================================================================
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name        = "org-workspaces-sg"
    Description = "WorkSpaces security group with full AD protocol support"
  })
}

# ------------------------------------------------------------------------------
# IP ACCESS CONTROL GROUP
# Controls which IP addresses can access WorkSpaces
# ------------------------------------------------------------------------------
variable "trusted_cidrs" {
  description = "List of trusted CIDR blocks for WorkSpaces client access"
  type = list(object({
    source      = string
    description = string
  }))
  default = [
    {
      source      = "10.0.0.0/8"
      description = "Private RFC1918 Class A"
    },
    {
      source      = "172.16.0.0/12"
      description = "Private RFC1918 Class B"
    },
    {
      source      = "192.168.0.0/16"
      description = "Private RFC1918 Class C"
    }
  ]
}

resource "aws_workspaces_ip_group" "trusted" {
  name        = "org-workspaces-trusted-networks"
  description = "Trusted networks for WorkSpaces client access"

  dynamic "rules" {
    for_each = var.trusted_cidrs
    content {
      source      = rules.value.source
      description = rules.value.description
    }
  }

  tags = merge(var.tags, {
    Name = "org-workspaces-ip-group"
  })
}

# ------------------------------------------------------------------------------
# IAM ROLE: workspaces_DefaultRole
# Required by AWS WorkSpaces to perform operations on your behalf
# This role must exist before registering a WorkSpaces directory
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "workspaces_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["workspaces.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "workspaces_default" {
  name               = "workspaces_DefaultRole"
  assume_role_policy = data.aws_iam_policy_document.workspaces_assume_role.json

  tags = merge(var.tags, {
    Name = "workspaces_DefaultRole"
  })
}

resource "aws_iam_role_policy_attachment" "workspaces_default_service" {
  role       = aws_iam_role.workspaces_default.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonWorkSpacesServiceAccess"
}

resource "aws_iam_role_policy_attachment" "workspaces_default_self_service" {
  role       = aws_iam_role.workspaces_default.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonWorkSpacesSelfServiceAccess"
}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------
locals {
  # Use directory_subnet_ids for registration if provided, otherwise fall back to subnet_ids
  # Directory registration MUST use subnets in standard AZs (where AD DCs are), NOT Local Zones
  registration_subnet_ids = length(var.directory_subnet_ids) > 0 ? var.directory_subnet_ids : var.subnet_ids
}

# ------------------------------------------------------------------------------
# WORKSPACES DIRECTORY REGISTRATION
# Registers the Managed AD with AWS WorkSpaces service
#
# IMPORTANT: subnet_ids here must be in standard Availability Zones where the
# AD domain controllers are deployed, NOT in Local Zones. Local Zone subnets
# can be used when launching WorkSpaces instances after registration.
# ------------------------------------------------------------------------------
resource "aws_workspaces_directory" "this" {
  directory_id = var.directory_id
  subnet_ids   = length(local.registration_subnet_ids) >= 2 ? slice(local.registration_subnet_ids, 0, 2) : local.registration_subnet_ids
  ip_group_ids = [aws_workspaces_ip_group.trusted.id]

  # Self-service permissions for users
  self_service_permissions {
    change_compute_type  = true
    increase_volume_size = true
    rebuild_workspace    = true
    restart_workspace    = true
    switch_running_mode  = true
  }

  # Device access policies
  workspace_access_properties {
    device_type_android    = "ALLOW"
    device_type_chromeos   = "ALLOW"
    device_type_ios        = "ALLOW"
    device_type_linux      = "ALLOW"
    device_type_osx        = "ALLOW"
    device_type_web        = "ALLOW"
    device_type_windows    = "ALLOW"
    device_type_zeroclient = "ALLOW"
  }

  # WorkSpace creation properties
  workspace_creation_properties {
    enable_internet_access              = var.enable_internet_access
    enable_maintenance_mode             = var.enable_maintenance_mode
    user_enabled_as_local_administrator = false
    custom_security_group_id            = aws_security_group.workspaces.id
    default_ou                          = var.default_ou != "" ? var.default_ou : null
  }

  tags = merge(var.tags, {
    Name = "org-workspaces-directory"
  })

  # Ensure IAM role exists before registering directory
  depends_on = [
    aws_iam_role.workspaces_default,
    aws_iam_role_policy_attachment.workspaces_default_service,
    aws_iam_role_policy_attachment.workspaces_default_self_service
  ]
}
