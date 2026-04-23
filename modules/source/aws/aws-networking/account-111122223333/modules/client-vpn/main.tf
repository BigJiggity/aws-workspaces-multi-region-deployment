# ==============================================================================
# MODULE: AWS CLIENT VPN
# 
# Creates an AWS Client VPN endpoint for remote user access.
# Traffic flows through Network Firewall for inspection before reaching
# private resources.
#
# Architecture:
#   User → Client VPN Endpoint → VPN Subnets → Firewall → Private Subnets
#
# Authentication Options:
#   - Certificate-based (default, self-signed certs generated)
#   - Active Directory (optional, requires directory_id)
#   - SAML (optional, requires saml_provider_arn)
#
# Prerequisites:
#   - Network Firewall deployed with endpoints
#   - Private subnets exist for target resources
# ==============================================================================

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------
locals {
  az_count    = length(var.azs)
  az_suffixes = [for az in var.azs : element(split("-", az), length(split("-", az)) - 1)]

  # VPC tag value - use name if provided, otherwise ID
  vpc_tag = var.vpc_name != "" ? var.vpc_name : var.vpc_id

  # Common tags following Cloud-Tagging-Standards.md
  # Provider default_tags (Project, Environment, ManagedBy, Owner) are inherited
  common_tags = merge(var.tags, {
    Application = var.application
    Criticality = var.criticality
    DataClass   = var.data_class
  })
}

# ==============================================================================
# VPN SUBNETS
# Dedicated subnets for Client VPN endpoint ENIs
# ==============================================================================
resource "aws_subnet" "vpn" {
  count = local.az_count

  vpc_id            = var.vpc_id
  cidr_block        = var.vpn_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpn-${local.az_suffixes[count.index]}"
    Tier = "vpn"
    VPC  = local.vpc_tag
  })
}

# ==============================================================================
# VPN ROUTE TABLE
# Routes traffic through Network Firewall for inspection
# ==============================================================================
resource "aws_route_table" "vpn" {
  vpc_id = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpn-rt"
    Tier = "vpn"
  })
}

# Default route → Firewall (for internet access if split-tunnel disabled)
resource "aws_route" "vpn_to_firewall_default" {
  route_table_id         = aws_route_table.vpn.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = var.firewall_endpoint_ids[0]
}

# Route to private subnets → Firewall
resource "aws_route" "vpn_to_firewall_private" {
  count = length(var.private_subnet_cidrs)

  route_table_id         = aws_route_table.vpn.id
  destination_cidr_block = var.private_subnet_cidrs[count.index]
  vpc_endpoint_id        = var.firewall_endpoint_ids[count.index % length(var.firewall_endpoint_ids)]
}

# Route to management subnets → Firewall
resource "aws_route" "vpn_to_firewall_management" {
  count = length(var.management_subnet_cidrs)

  route_table_id         = aws_route_table.vpn.id
  destination_cidr_block = var.management_subnet_cidrs[count.index]
  vpc_endpoint_id        = var.firewall_endpoint_ids[count.index % length(var.firewall_endpoint_ids)]
}

# Route to peer VPCs → Firewall (for cross-region access)
resource "aws_route" "vpn_to_firewall_peer_vpcs" {
  count = length(var.peer_vpc_cidrs)

  route_table_id         = aws_route_table.vpn.id
  destination_cidr_block = var.peer_vpc_cidrs[count.index]
  vpc_endpoint_id        = var.firewall_endpoint_ids[0]
}

# Route table associations
resource "aws_route_table_association" "vpn" {
  count = local.az_count

  subnet_id      = aws_subnet.vpn[count.index].id
  route_table_id = aws_route_table.vpn.id
}

# ==============================================================================
# TLS CERTIFICATES (Self-Signed)
# For production, replace with ACM Private CA certificates
# ==============================================================================

# CA Private Key
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# CA Certificate
resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "${var.name_prefix}-vpn-ca"
    organization = var.certificate_organization
  }

  validity_period_hours = var.certificate_validity_hours
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# Server Private Key
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Server Certificate Request
resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name  = "${var.name_prefix}-vpn.${var.certificate_domain}"
    organization = var.certificate_organization
  }

  dns_names = [
    "${var.name_prefix}-vpn.${var.certificate_domain}",
    "*.${var.certificate_domain}"
  ]
}

# Server Certificate (signed by CA)
resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = var.certificate_validity_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Client Private Key
resource "tls_private_key" "client" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Client Certificate Request
resource "tls_cert_request" "client" {
  private_key_pem = tls_private_key.client.private_key_pem

  subject {
    common_name  = "${var.name_prefix}-vpn-client"
    organization = var.certificate_organization
  }
}

# Client Certificate (signed by CA)
resource "tls_locally_signed_cert" "client" {
  cert_request_pem   = tls_cert_request.client.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = var.certificate_validity_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# ==============================================================================
# ACM CERTIFICATES
# Import self-signed certificates into ACM for Client VPN
# ==============================================================================

# Server Certificate in ACM
resource "aws_acm_certificate" "server" {
  private_key       = tls_private_key.server.private_key_pem
  certificate_body  = tls_locally_signed_cert.server.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpn-server-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Client Certificate in ACM (for mutual TLS)
resource "aws_acm_certificate" "client" {
  private_key       = tls_private_key.client.private_key_pem
  certificate_body  = tls_locally_signed_cert.client.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpn-client-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# SECRETS MANAGER - Store Client Credentials
# Stores client certificate and key for distribution
# ==============================================================================
resource "aws_secretsmanager_secret" "vpn_client_config" {
  name        = "${var.name_prefix}-vpn-client-credentials"
  description = "Client VPN credentials for ${var.name_prefix}"

  tags = merge(local.common_tags, {
    Name      = "${var.name_prefix}-vpn-client-credentials"
    DataClass = "Confidential" # Override - credentials are confidential
  })
}

resource "aws_secretsmanager_secret_version" "vpn_client_config" {
  secret_id = aws_secretsmanager_secret.vpn_client_config.id
  secret_string = jsonencode({
    ca_certificate     = tls_self_signed_cert.ca.cert_pem
    client_certificate = tls_locally_signed_cert.client.cert_pem
    client_private_key = tls_private_key.client.private_key_pem
  })
}

# ==============================================================================
# CLOUDWATCH LOG GROUP
# For Client VPN connection logging
# ==============================================================================
resource "aws_cloudwatch_log_group" "vpn" {
  name              = "/aws/client-vpn/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpn-logs"
  })
}

resource "aws_cloudwatch_log_stream" "vpn" {
  name           = "connection-logs"
  log_group_name = aws_cloudwatch_log_group.vpn.name
}

# ==============================================================================
# SECURITY GROUP
# Controls traffic from VPN clients
# ==============================================================================
resource "aws_security_group" "vpn" {
  name        = "${var.name_prefix}-client-vpn-sg"
  description = "Security group for Client VPN endpoint"
  vpc_id      = var.vpc_id

  # Allow all outbound (filtered by firewall)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound (inspected by Network Firewall)"
  }

  tags = merge(local.common_tags, {
    Name    = "${var.name_prefix}-client-vpn-sg"
    Service = "client-vpn"
  })
}

# ==============================================================================
# CLIENT VPN ENDPOINT
# ==============================================================================
resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = "${var.name_prefix} Client VPN"
  server_certificate_arn = aws_acm_certificate.server.arn
  client_cidr_block      = var.vpn_client_cidr

  # Authentication - Certificate-based (mutual TLS)
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client.arn
  }

  # Connection logging
  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.vpn.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.vpn.name
  }

  # Network configuration
  split_tunnel       = var.enable_split_tunnel
  transport_protocol = "udp"
  vpn_port           = 443

  # Security
  security_group_ids = [aws_security_group.vpn.id]
  vpc_id             = var.vpc_id

  # DNS - Use VPC DNS for internal resolution
  dns_servers = var.dns_servers

  # Session timeout
  session_timeout_hours = var.session_timeout_hours

  # Self-service portal (optional)
  self_service_portal = var.enable_self_service_portal ? "enabled" : "disabled"

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-client-vpn"
  })
}

# ==============================================================================
# VPN SUBNET ASSOCIATIONS
# Associates VPN endpoint with subnets for ENI placement
# ==============================================================================
resource "aws_ec2_client_vpn_network_association" "this" {
  count = local.az_count

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = aws_subnet.vpn[count.index].id

  lifecycle {
    # Prevent destroy/recreate which disconnects users
    create_before_destroy = true
  }
}

# ==============================================================================
# VPN AUTHORIZATION RULES
# Controls which networks VPN clients can access
# ==============================================================================

# Authorize access to private subnets
resource "aws_ec2_client_vpn_authorization_rule" "private" {
  count = length(var.private_subnet_cidrs)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = var.private_subnet_cidrs[count.index]
  authorize_all_groups   = true
  description            = "Allow access to private subnet ${count.index + 1}"

  depends_on = [aws_ec2_client_vpn_network_association.this]
}

# Authorize access to management subnets
resource "aws_ec2_client_vpn_authorization_rule" "management" {
  count = length(var.management_subnet_cidrs)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = var.management_subnet_cidrs[count.index]
  authorize_all_groups   = true
  description            = "Allow access to management subnet ${count.index + 1}"

  depends_on = [aws_ec2_client_vpn_network_association.this]
}

# Authorize internet access (if split tunnel disabled)
resource "aws_ec2_client_vpn_authorization_rule" "internet" {
  count = var.enable_split_tunnel ? 0 : 1

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = "0.0.0.0/0"
  authorize_all_groups   = true
  description            = "Allow internet access through VPN"

  depends_on = [aws_ec2_client_vpn_network_association.this]
}

# ==============================================================================
# VPN ROUTES
# Defines routing for VPN clients
# ==============================================================================

# Route to VPC CIDR (for all internal resources)
resource "aws_ec2_client_vpn_route" "vpc" {
  count = local.az_count

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = var.vpc_cidr
  target_vpc_subnet_id   = aws_subnet.vpn[count.index].id
  description            = "Route to VPC via ${var.azs[count.index]}"

  depends_on = [aws_ec2_client_vpn_network_association.this]
}

# Route to internet (if split tunnel disabled)
resource "aws_ec2_client_vpn_route" "internet" {
  count = var.enable_split_tunnel ? 0 : local.az_count

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = "0.0.0.0/0"
  target_vpc_subnet_id   = aws_subnet.vpn[count.index].id
  description            = "Internet route via ${var.azs[count.index]}"

  depends_on = [aws_ec2_client_vpn_network_association.this]
}

# Routes to peer VPCs (cross-region access)
resource "aws_ec2_client_vpn_route" "peer_vpcs" {
  count = length(var.peer_vpc_cidrs) * local.az_count

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = var.peer_vpc_cidrs[floor(count.index / local.az_count)]
  target_vpc_subnet_id   = aws_subnet.vpn[count.index % local.az_count].id
  description            = "Route to peer VPC ${var.peer_vpc_cidrs[floor(count.index / local.az_count)]}"

  depends_on = [aws_ec2_client_vpn_network_association.this]
}

# ==============================================================================
# AUTHORIZATION FOR PEER VPCs
# ==============================================================================
resource "aws_ec2_client_vpn_authorization_rule" "peer_vpcs" {
  count = length(var.peer_vpc_cidrs)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = var.peer_vpc_cidrs[count.index]
  authorize_all_groups   = true
  description            = "Allow access to peer VPC ${var.peer_vpc_cidrs[count.index]}"

  depends_on = [aws_ec2_client_vpn_network_association.this]
}
