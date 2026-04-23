# ==============================================================================
# ROOT MODULE: Generic AWS AD account-111122223333
# Self-Managed Active Directory Domain Controllers
#
# Architecture:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                         US-EAST-2 (Primary Site)                            │
# │  ┌───────────────────────────────────────────────────────────────────────┐  │
# │  │              VPC 10.0.0.0/16 (Management Subnets)                       │  │
# │  │                                                                         │  │
# │  │  ┌──────────────────────┐                                              │  │
# │  │  │   DC01 (PDC)         │                                              │  │
# │  │  │   10.0.12.10          │                                              │  │
# │  │  │   us-east-2a         │                                              │  │
# │  │  │   Windows 2022       │                                              │  │
# │  │  └──────────────────────┘                                              │  │
# │  └───────────────────────────────────────────────────────────────────────┘  │
# └─────────────────────────────────────────────────────────────────────────────┘
#                                    │
#                         TGW Peering│(AD Replication)
#                                    │
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      US-EAST-1 (WorkSpaces Site)                            │
# │  ┌───────────────────────────────────────────────────────────────────────┐  │
# │  │              VPC 10.1.0.0/16 (Management Subnets)                       │  │
# │  │                                                                         │  │
# │  │  ┌──────────────────────┐                                              │  │
# │  │  │   DC02 (Secondary)   │                                              │  │
# │  │  │   10.1.12.10          │                                              │  │
# │  │  │   us-east-1a         │                                              │  │
# │  │  │   Windows 2022       │                                              │  │
# │  │  └──────────────────────┘                                              │  │
# │  └───────────────────────────────────────────────────────────────────────┘  │
# └─────────────────────────────────────────────────────────────────────────────┘
#                                    │
#                         TGW Peering│(AD Replication)
#                                    │
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │                      AP-SOUTHEAST-1 (Manila Site)                           │
# │  ┌───────────────────────────────────────────────────────────────────────┐  │
# │  │              VPC 10.2.0.0/16 (Management Subnets)                       │  │
# │  │                                                                         │  │
# │  │  ┌──────────────────────┐                                              │  │
# │  │  │   DC03 (Replica)     │                                              │  │
# │  │  │   10.2.10.10          │                                              │  │
# │  │  │   ap-southeast-1a    │                                              │  │
# │  │  │   Windows 2022       │                                              │  │
# │  │  └──────────────────────┘                                              │  │
# │  └───────────────────────────────────────────────────────────────────────┘  │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# Domain: example.internal
# NetBIOS: `ORG`
# ==============================================================================

# ------------------------------------------------------------------------------
# DATA SOURCES – REMOTE STATE
# ------------------------------------------------------------------------------
data "terraform_remote_state" "vpc_firewall" {
  backend = "s3"

  config = {
    bucket = var.vpc_firewall_state_bucket
    key    = var.vpc_firewall_state_key
    region = var.vpc_firewall_state_region
  }
}

data "terraform_remote_state" "use1_networking" {
  backend = "s3"

  config = {
    bucket = var.use1_networking_state_bucket
    key    = var.use1_networking_state_key
    region = var.use1_networking_state_region
  }
}

data "terraform_remote_state" "landing_zone" {
  backend = "s3"

  config = {
    bucket = var.landing_zone_state_bucket
    key    = var.landing_zone_state_key
    region = var.landing_zone_state_region
  }
}

# ------------------------------------------------------------------------------
# DATA SOURCES – AMIs
# Windows Server 2022 Base AMI (latest)
# ------------------------------------------------------------------------------
data "aws_ami" "windows_2022_use2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_ami" "windows_2022_use1" {
  provider    = aws.virginia
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_ami" "windows_2022_apse1" {
  provider    = aws.singapore
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------
locals {
  # US-East-2 VPC outputs (DC01)
  use2_vpc_id             = data.terraform_remote_state.vpc_firewall.outputs.vpc_id
  use2_vpc_cidr           = data.terraform_remote_state.vpc_firewall.outputs.vpc_cidr
  use2_management_subnets = data.terraform_remote_state.vpc_firewall.outputs.management_subnet_ids

  # US-East-1 VPC outputs (DC02)
  use1_vpc_id             = data.terraform_remote_state.use1_networking.outputs.vpc_id
  use1_vpc_cidr           = data.terraform_remote_state.use1_networking.outputs.vpc_cidr
  use1_management_subnets = data.terraform_remote_state.use1_networking.outputs.management_subnet_ids

  # AP-Southeast-1 VPC outputs (DC03)
  apse1_vpc_id             = data.terraform_remote_state.landing_zone.outputs.vpc_id
  apse1_vpc_cidr           = var.landing_zone_vpc_cidr
  apse1_management_subnets = data.terraform_remote_state.landing_zone.outputs.management_subnets

  # Common tags
  common_tags = merge(var.tags, {
    Project     = "account-111122223333"
    Domain      = var.ad_domain_name
    Environment = "account-111122223333"
    ManagedBy   = "terraform"
  })
}

# ==============================================================================
# EC2 KEY PAIR
# Creates key pairs for RDP access via Fleet Manager
# ==============================================================================
resource "tls_private_key" "dc_key" {
  count     = var.key_pair_name == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "dc_use2" {
  count      = var.key_pair_name == "" ? 1 : 0
  key_name   = "org-ad-dc-key-use2"
  public_key = tls_private_key.dc_key[0].public_key_openssh

  tags = merge(local.common_tags, {
    Name   = "org-ad-dc-key-use2"
    Region = "us-east-2"
  })
}

resource "aws_key_pair" "dc_use1" {
  count      = var.key_pair_name == "" ? 1 : 0
  provider   = aws.virginia
  key_name   = "org-ad-dc-key-use1"
  public_key = tls_private_key.dc_key[0].public_key_openssh

  tags = merge(local.common_tags, {
    Name   = "org-ad-dc-key-use1"
    Region = "us-east-1"
  })
}

resource "aws_key_pair" "dc_apse1" {
  count      = var.key_pair_name == "" ? 1 : 0
  provider   = aws.singapore
  key_name   = "org-ad-dc-key-apse1"
  public_key = tls_private_key.dc_key[0].public_key_openssh

  tags = merge(local.common_tags, {
    Name   = "org-ad-dc-key-apse1"
    Region = "ap-southeast-1"
  })
}

# Store private key in Secrets Manager for retrieval
resource "aws_secretsmanager_secret" "dc_private_key" {
  count       = var.key_pair_name == "" ? 1 : 0
  name        = "account-111122223333/dc-private-key"
  description = "Private key for Domain Controller EC2 instances"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "dc_private_key" {
  count         = var.key_pair_name == "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.dc_private_key[0].id
  secret_string = tls_private_key.dc_key[0].private_key_pem
}

locals {
  # Use provided key pair name or the created one
  use2_key_name  = var.key_pair_name != "" ? var.key_pair_name : aws_key_pair.dc_use2[0].key_name
  use1_key_name  = var.key_pair_name != "" ? var.key_pair_name : aws_key_pair.dc_use1[0].key_name
  apse1_key_name = var.key_pair_name != "" ? var.key_pair_name : aws_key_pair.dc_apse1[0].key_name
}

# ==============================================================================
# IAM ROLE FOR DOMAIN CONTROLLERS
# Enables SSM Session Manager and CloudWatch logging
# ==============================================================================
resource "aws_iam_role" "dc_role" {
  name = "org-ad-dc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "dc_ssm" {
  role       = aws_iam_role.dc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "dc_cloudwatch" {
  role       = aws_iam_role.dc_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "dc_profile" {
  name = "org-ad-dc-profile"
  role = aws_iam_role.dc_role.name

  tags = local.common_tags
}

# ==============================================================================
# SECURITY GROUP – US-EAST-2 DOMAIN CONTROLLER (DC01)
# ==============================================================================
resource "aws_security_group" "dc_use2" {
  name        = "org-ad-dc-use2-sg"
  description = "Security group for AD Domain Controllers in us-east-2"
  vpc_id      = local.use2_vpc_id

  tags = merge(local.common_tags, {
    Name = "org-ad-dc-use2-sg"
  })

  lifecycle {
    ignore_changes = [description]
  }
}

# DNS (TCP/UDP 53)
resource "aws_vpc_security_group_ingress_rule" "dc_use2_dns_tcp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "DNS TCP"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_dns_udp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "DNS UDP"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_dns_tcp_5" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "DNS TCP from 5.x"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-TCP-5x" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_dns_udp_5" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "DNS UDP from 5.x"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-UDP-5x" }
}

# Kerberos, LDAP, SMB, RPC, etc.
resource "aws_vpc_security_group_ingress_rule" "dc_use2_kerberos_tcp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "Kerberos TCP"
  ip_protocol       = "tcp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kerberos-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_kerberos_udp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "Kerberos UDP"
  ip_protocol       = "udp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kerberos-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_rpc" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "RPC Endpoint Mapper"
  ip_protocol       = "tcp"
  from_port         = 135
  to_port           = 135
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "RPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_netbios_tcp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "NetBIOS TCP"
  ip_protocol       = "tcp"
  from_port         = 137
  to_port           = 139
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "NetBIOS-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_netbios_udp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "NetBIOS UDP"
  ip_protocol       = "udp"
  from_port         = 137
  to_port           = 139
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "NetBIOS-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_ldap_tcp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "LDAP TCP"
  ip_protocol       = "tcp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "LDAP-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_ldap_udp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "LDAP UDP"
  ip_protocol       = "udp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "LDAP-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_smb" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "SMB"
  ip_protocol       = "tcp"
  from_port         = 445
  to_port           = 445
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "SMB" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_kpasswd_tcp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "Kerberos Password Change TCP"
  ip_protocol       = "tcp"
  from_port         = 464
  to_port           = 464
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kpasswd-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_kpasswd_udp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "Kerberos Password Change UDP"
  ip_protocol       = "udp"
  from_port         = 464
  to_port           = 464
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kpasswd-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_ldaps" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "LDAPS"
  ip_protocol       = "tcp"
  from_port         = 636
  to_port           = 636
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "LDAPS" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_gc" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "Global Catalog"
  ip_protocol       = "tcp"
  from_port         = 3268
  to_port           = 3269
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "GlobalCatalog" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_rdp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "RDP"
  ip_protocol       = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "RDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_winrm" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "WinRM"
  ip_protocol       = "tcp"
  from_port         = 5985
  to_port           = 5986
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "WinRM" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_rpc_dynamic" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "RPC Dynamic Ports"
  ip_protocol       = "tcp"
  from_port         = 49152
  to_port           = 65535
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "RPC-Dynamic" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use2_icmp" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "ICMP"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "ICMP" }
}

resource "aws_vpc_security_group_egress_rule" "dc_use2_egress" {
  security_group_id = aws_security_group.dc_use2.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags              = { Name = "AllOutbound" }
}

# ==============================================================================
# SECURITY GROUP – US-EAST-1 DOMAIN CONTROLLER (DC02)
# ==============================================================================
resource "aws_security_group" "dc_use1" {
  provider    = aws.virginia
  name        = "org-ad-dc-use1-sg"
  description = "Security group for AD Domain Controller in us-east-1"
  vpc_id      = local.use1_vpc_id

  tags = merge(local.common_tags, {
    Name = "org-ad-dc-use1-sg"
  })
}

# DNS (TCP/UDP 53)
resource "aws_vpc_security_group_ingress_rule" "dc_use1_dns_tcp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "DNS TCP"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_dns_udp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "DNS UDP"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_dns_tcp_5" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "DNS TCP from 5.x"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-TCP-5x" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_dns_udp_5" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "DNS UDP from 5.x"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-UDP-5x" }
}

# Kerberos, LDAP, SMB, RPC, etc.
resource "aws_vpc_security_group_ingress_rule" "dc_use1_kerberos_tcp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "Kerberos TCP"
  ip_protocol       = "tcp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kerberos-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_kerberos_udp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "Kerberos UDP"
  ip_protocol       = "udp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kerberos-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_rpc" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "RPC Endpoint Mapper"
  ip_protocol       = "tcp"
  from_port         = 135
  to_port           = 135
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "RPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_netbios_tcp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "NetBIOS TCP"
  ip_protocol       = "tcp"
  from_port         = 137
  to_port           = 139
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "NetBIOS-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_netbios_udp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "NetBIOS UDP"
  ip_protocol       = "udp"
  from_port         = 137
  to_port           = 139
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "NetBIOS-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_ldap_tcp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "LDAP TCP"
  ip_protocol       = "tcp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "LDAP-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_ldap_udp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "LDAP UDP"
  ip_protocol       = "udp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "LDAP-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_smb" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "SMB"
  ip_protocol       = "tcp"
  from_port         = 445
  to_port           = 445
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "SMB" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_kpasswd_tcp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "Kerberos Password Change TCP"
  ip_protocol       = "tcp"
  from_port         = 464
  to_port           = 464
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kpasswd-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_kpasswd_udp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "Kerberos Password Change UDP"
  ip_protocol       = "udp"
  from_port         = 464
  to_port           = 464
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kpasswd-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_ldaps" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "LDAPS"
  ip_protocol       = "tcp"
  from_port         = 636
  to_port           = 636
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "LDAPS" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_gc" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "Global Catalog"
  ip_protocol       = "tcp"
  from_port         = 3268
  to_port           = 3269
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "GlobalCatalog" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_rdp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "RDP"
  ip_protocol       = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "RDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_winrm" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "WinRM"
  ip_protocol       = "tcp"
  from_port         = 5985
  to_port           = 5986
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "WinRM" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_rpc_dynamic" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "RPC Dynamic Ports"
  ip_protocol       = "tcp"
  from_port         = 49152
  to_port           = 65535
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "RPC-Dynamic" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_use1_icmp" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "ICMP"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "ICMP" }
}

resource "aws_vpc_security_group_egress_rule" "dc_use1_egress" {
  provider          = aws.virginia
  security_group_id = aws_security_group.dc_use1.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags              = { Name = "AllOutbound" }
}

# ==============================================================================
# SECURITY GROUP – AP-SOUTHEAST-1 DOMAIN CONTROLLER (DC03)
# ==============================================================================
resource "aws_security_group" "dc_apse1" {
  provider    = aws.singapore
  name        = "org-ad-dc-apse1-sg"
  description = "Security group for AD Domain Controller in ap-southeast-1"
  vpc_id      = local.apse1_vpc_id

  tags = merge(local.common_tags, {
    Name = "org-ad-dc-apse1-sg"
  })
}

# DNS (TCP/UDP 53)
resource "aws_vpc_security_group_ingress_rule" "dc_apse1_dns_tcp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "DNS TCP"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_dns_udp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "DNS UDP"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_dns_tcp_5" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "DNS TCP from 5.x"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-TCP-5x" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_dns_udp_5" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "DNS UDP from 5.x"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "DNS-UDP-5x" }
}

# Kerberos, LDAP, SMB, RPC, etc.
resource "aws_vpc_security_group_ingress_rule" "dc_apse1_kerberos_tcp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "Kerberos TCP"
  ip_protocol       = "tcp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kerberos-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_kerberos_udp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "Kerberos UDP"
  ip_protocol       = "udp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kerberos-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_rpc" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "RPC Endpoint Mapper"
  ip_protocol       = "tcp"
  from_port         = 135
  to_port           = 135
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "RPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_netbios_tcp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "NetBIOS TCP"
  ip_protocol       = "tcp"
  from_port         = 137
  to_port           = 139
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "NetBIOS-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_netbios_udp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "NetBIOS UDP"
  ip_protocol       = "udp"
  from_port         = 137
  to_port           = 139
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "NetBIOS-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_ldap_tcp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "LDAP TCP"
  ip_protocol       = "tcp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "LDAP-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_ldap_udp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "LDAP UDP"
  ip_protocol       = "udp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "LDAP-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_smb" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "SMB"
  ip_protocol       = "tcp"
  from_port         = 445
  to_port           = 445
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "SMB" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_kpasswd_tcp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "Kerberos Password Change TCP"
  ip_protocol       = "tcp"
  from_port         = 464
  to_port           = 464
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kpasswd-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_kpasswd_udp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "Kerberos Password Change UDP"
  ip_protocol       = "udp"
  from_port         = 464
  to_port           = 464
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "Kpasswd-UDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_ldaps" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "LDAPS"
  ip_protocol       = "tcp"
  from_port         = 636
  to_port           = 636
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "LDAPS" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_gc" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "Global Catalog"
  ip_protocol       = "tcp"
  from_port         = 3268
  to_port           = 3269
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "GlobalCatalog" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_rdp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "RDP"
  ip_protocol       = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "RDP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_winrm" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "WinRM"
  ip_protocol       = "tcp"
  from_port         = 5985
  to_port           = 5986
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "WinRM" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_rpc_dynamic" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "RPC Dynamic Ports"
  ip_protocol       = "tcp"
  from_port         = 49152
  to_port           = 65535
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "RPC-Dynamic" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_apse1_icmp" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "ICMP"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = "10.0.0.0/8"
  tags              = { Name = "ICMP" }
}

resource "aws_vpc_security_group_egress_rule" "dc_apse1_egress" {
  provider          = aws.singapore
  security_group_id = aws_security_group.dc_apse1.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags              = { Name = "AllOutbound" }
}

# ==============================================================================
# EC2 INSTANCES – DOMAIN CONTROLLERS
# ==============================================================================

# DC01 - Primary Domain Controller (us-east-2a)
resource "aws_instance" "dc01" {
  ami                    = data.aws_ami.windows_2022_use2.id
  instance_type          = var.instance_type
  subnet_id              = local.use2_management_subnets[0]
  private_ip             = var.dc01_private_ip
  vpc_security_group_ids = [aws_security_group.dc_use2.id]
  iam_instance_profile   = aws_iam_instance_profile.dc_profile.name
  key_name               = local.use2_key_name

  user_data = <<-EOF
    <powershell>
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    Rename-Computer -NewName "DC01" -Force
    </powershell>
  EOF

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags                  = merge(local.common_tags, { Name = "org-dc01-root" })
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(local.common_tags, {
    Name   = "org-dc01"
    Role   = "PrimaryDC"
    Domain = var.ad_domain_name
    Site   = "US-East-2"
  })
}

# DC02 - Secondary Domain Controller (us-east-1a)
resource "aws_instance" "dc02" {
  provider               = aws.virginia
  ami                    = data.aws_ami.windows_2022_use1.id
  instance_type          = var.instance_type
  subnet_id              = local.use1_management_subnets[0]
  private_ip             = var.dc02_private_ip
  vpc_security_group_ids = [aws_security_group.dc_use1.id]
  iam_instance_profile   = aws_iam_instance_profile.dc_profile.name
  key_name               = local.use1_key_name

  user_data = <<-EOF
    <powershell>
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    Rename-Computer -NewName "DC02" -Force
    </powershell>
  EOF

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags                  = merge(local.common_tags, { Name = "org-dc02-root" })
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(local.common_tags, {
    Name   = "org-dc02"
    Role   = "SecondaryDC"
    Domain = var.ad_domain_name
    Site   = "US-East-1"
  })
}

# DC03 - Replica Domain Controller (ap-southeast-1a)
resource "aws_instance" "dc03" {
  provider               = aws.singapore
  ami                    = data.aws_ami.windows_2022_apse1.id
  instance_type          = var.instance_type
  subnet_id              = local.apse1_management_subnets[0]
  private_ip             = var.dc03_private_ip
  vpc_security_group_ids = [aws_security_group.dc_apse1.id]
  iam_instance_profile   = aws_iam_instance_profile.dc_profile.name
  key_name               = local.apse1_key_name

  user_data = <<-EOF
    <powershell>
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    Rename-Computer -NewName "DC03" -Force
    </powershell>
  EOF

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags                  = merge(local.common_tags, { Name = "org-dc03-root" })
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(local.common_tags, {
    Name   = "org-dc03"
    Role   = "ReplicaDC"
    Domain = var.ad_domain_name
    Site   = "AP-Southeast-1"
  })
}

# ==============================================================================
# ROUTE53 PRIVATE HOSTED ZONE – example.internal
# ==============================================================================
resource "aws_route53_zone" "org_int" {
  name    = var.ad_domain_name
  comment = "Private hosted zone for ${var.ad_domain_name} AD domain"

  vpc {
    vpc_id = local.use2_vpc_id
  }

  tags = merge(local.common_tags, {
    Name = "${var.ad_domain_name}-zone"
  })

  lifecycle {
    ignore_changes = [vpc]
  }
}

# Associate with us-east-1 VPC
resource "aws_route53_zone_association" "org_int_use1" {
  provider = aws.virginia
  zone_id  = aws_route53_zone.org_int.zone_id
  vpc_id   = local.use1_vpc_id
}

# Associate with ap-southeast-1 VPC
resource "aws_route53_zone_association" "org_int_apse1" {
  provider = aws.singapore
  zone_id  = aws_route53_zone.org_int.zone_id
  vpc_id   = local.apse1_vpc_id
}

# ==============================================================================
# ROUTE53 A RECORDS FOR DOMAIN CONTROLLERS
# ==============================================================================
resource "aws_route53_record" "dc01" {
  zone_id = aws_route53_zone.org_int.zone_id
  name    = "dc01.${var.ad_domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.dc01_private_ip]
}

resource "aws_route53_record" "dc02" {
  zone_id = aws_route53_zone.org_int.zone_id
  name    = "dc02.${var.ad_domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.dc02_private_ip]
}

resource "aws_route53_record" "dc03" {
  zone_id = aws_route53_zone.org_int.zone_id
  name    = "dc03.${var.ad_domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.dc03_private_ip]
}

# ==============================================================================
# ROUTE53 RESOLVER ENDPOINTS & RULES
# Forward DNS queries for example.internal to the domain controllers
# ==============================================================================

# Outbound Resolver Endpoint (us-east-2)
resource "aws_route53_resolver_endpoint" "use2_outbound" {
  name               = "org-resolver-outbound-use2"
  direction          = "OUTBOUND"
  security_group_ids = [aws_security_group.dc_use2.id]

  ip_address {
    subnet_id = local.use2_management_subnets[0]
  }

  ip_address {
    subnet_id = local.use2_management_subnets[1]
  }

  tags = merge(local.common_tags, {
    Name = "org-resolver-outbound-use2"
  })
}

# Resolver Rule for example.internal (forward to DC01 only in us-east-2)
resource "aws_route53_resolver_rule" "org_int_forward" {
  name                 = "org-int-forward"
  domain_name          = var.ad_domain_name
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.use2_outbound.id

  target_ip {
    ip = aws_instance.dc01.private_ip
  }

  tags = merge(local.common_tags, {
    Name = "org-int-forward-rule"
  })
}

# Associate rule with us-east-2 VPC
resource "aws_route53_resolver_rule_association" "org_int_use2" {
  resolver_rule_id = aws_route53_resolver_rule.org_int_forward.id
  vpc_id           = local.use2_vpc_id
}

# Share rule with us-east-1 and ap-southeast-1 via RAM
resource "aws_ram_resource_share" "resolver_rule_share" {
  name                      = "org-resolver-rule-share"
  allow_external_principals = false

  tags = merge(local.common_tags, {
    Name = "org-resolver-rule-share"
  })
}

resource "aws_ram_resource_association" "resolver_rule" {
  resource_arn       = aws_route53_resolver_rule.org_int_forward.arn
  resource_share_arn = aws_ram_resource_share.resolver_rule_share.arn
}

# Outbound Resolver Endpoint (us-east-1)
resource "aws_route53_resolver_endpoint" "use1_outbound" {
  provider           = aws.virginia
  name               = "org-resolver-outbound-use1"
  direction          = "OUTBOUND"
  security_group_ids = [aws_security_group.dc_use1.id]

  ip_address {
    subnet_id = local.use1_management_subnets[0]
  }

  ip_address {
    subnet_id = local.use1_management_subnets[1]
  }

  tags = merge(local.common_tags, {
    Name = "org-resolver-outbound-use1"
  })
}

# Resolver Rule for example.internal in us-east-1 (forward to DC02 local + DC01 fallback)
resource "aws_route53_resolver_rule" "org_int_forward_use1" {
  provider             = aws.virginia
  name                 = "org-int-forward-use1"
  domain_name          = var.ad_domain_name
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.use1_outbound.id

  # Local DC first for low latency
  target_ip {
    ip = aws_instance.dc02.private_ip
  }

  # Fallback to DC01
  target_ip {
    ip = aws_instance.dc01.private_ip
  }

  tags = merge(local.common_tags, {
    Name = "org-int-forward-rule-use1"
  })
}

# Associate rule with us-east-1 VPC
resource "aws_route53_resolver_rule_association" "org_int_use1" {
  provider         = aws.virginia
  resolver_rule_id = aws_route53_resolver_rule.org_int_forward_use1.id
  vpc_id           = local.use1_vpc_id
}

# Outbound Resolver Endpoint (ap-southeast-1)
resource "aws_route53_resolver_endpoint" "apse1_outbound" {
  provider           = aws.singapore
  name               = "org-resolver-outbound-apse1"
  direction          = "OUTBOUND"
  security_group_ids = [aws_security_group.dc_apse1.id]

  ip_address {
    subnet_id = local.apse1_management_subnets[0]
  }

  ip_address {
    subnet_id = local.apse1_management_subnets[1]
  }

  tags = merge(local.common_tags, {
    Name = "org-resolver-outbound-apse1"
  })
}

# Resolver Rule for example.internal in ap-southeast-1 (forward to DC03 + DC01 fallback)
resource "aws_route53_resolver_rule" "org_int_forward_apse1" {
  provider             = aws.singapore
  name                 = "org-int-forward-apse1"
  domain_name          = var.ad_domain_name
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.apse1_outbound.id

  # Local DC first for low latency
  target_ip {
    ip = aws_instance.dc03.private_ip
  }

  # Fallback to DC01
  target_ip {
    ip = aws_instance.dc01.private_ip
  }

  tags = merge(local.common_tags, {
    Name = "org-int-forward-rule-apse1"
  })
}

# Associate rule with ap-southeast-1 VPC
resource "aws_route53_resolver_rule_association" "org_int_apse1" {
  provider         = aws.singapore
  resolver_rule_id = aws_route53_resolver_rule.org_int_forward_apse1.id
  vpc_id           = local.apse1_vpc_id
}

# ==============================================================================
# SECRETS MANAGER – AD PASSWORDS
# ==============================================================================
resource "aws_secretsmanager_secret" "ad_passwords" {
  name        = "account-111122223333/ad-passwords"
  description = "Active Directory passwords for example.internal domain"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "ad_passwords" {
  secret_id = aws_secretsmanager_secret.ad_passwords.id
  secret_string = jsonencode({
    admin_password     = var.ad_admin_password
    safe_mode_password = var.ad_safe_mode_password
    domain_name        = var.ad_domain_name
    netbios_name       = var.ad_netbios_name
  })
}
