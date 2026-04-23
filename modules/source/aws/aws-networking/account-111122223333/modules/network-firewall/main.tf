# ==============================================================================
# SHARED MODULE: NETWORK-FIREWALL
# Deploys AWS Network Firewall with comprehensive traffic inspection rules
#
# Features:
#   - Drop-by-default policy
#   - Domain filtering (allowlist)
#   - WorkSpaces streaming protocols (PCoIP, WSP)
#   - Active Directory protocols
#   - Cross-region traffic rules
#   - Management subnet bypass
#   - CloudWatch logging
# ==============================================================================

# ------------------------------------------------------------------------------
# INPUT VARIABLES
# ------------------------------------------------------------------------------
variable "vpc_id" {
  description = "VPC ID where the firewall is deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "firewall_name" {
  description = "Name for the Network Firewall"
  type        = string
}

variable "inspection_subnet_ids" {
  description = "List of inspection subnet IDs for firewall endpoints"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = []
}

variable "management_subnet_cidrs" {
  description = "CIDR blocks for management subnets"
  type        = list(string)
  default     = []
}

variable "vdi_subnet_cidrs" {
  description = "CIDR blocks for VDI subnets (WorkSpaces)"
  type        = list(string)
  default     = []
}

variable "peer_vpc_cidrs" {
  description = "List of peer VPC CIDRs for cross-region traffic"
  type        = list(string)
  default     = []
}

variable "vpn_client_cidrs" {
  description = "CIDR blocks for VPN clients (for firewall rules)"
  type        = list(string)
  default     = []
}

variable "allowed_domains" {
  description = "List of domains to allow for outbound traffic"
  type        = list(string)
  default     = []
}

variable "enable_workspaces_rules" {
  description = "Enable WorkSpaces streaming protocol rules"
  type        = bool
  default     = true
}

variable "enable_ad_rules" {
  description = "Enable Active Directory protocol rules"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Whether to enable flow logging"
  type        = bool
  default     = true
}

variable "enable_alert_logs" {
  description = "Whether to enable alert logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain firewall logs"
  type        = number
  default     = 90
}

variable "delete_protection" {
  description = "Enable delete protection for the firewall"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------
locals {
  # Combine private and VDI subnets for WorkSpaces rules
  workspaces_cidrs = length(var.vdi_subnet_cidrs) > 0 ? var.vdi_subnet_cidrs : var.private_subnet_cidrs

  # Use a dummy CIDR if no peers defined (to avoid Terraform errors)
  peer_cidrs = length(var.peer_vpc_cidrs) > 0 ? var.peer_vpc_cidrs : ["10.255.255.255/32"]

  # VPN client CIDRs (use dummy if none defined)
  vpn_cidrs = length(var.vpn_client_cidrs) > 0 ? var.vpn_client_cidrs : ["10.255.255.251/32"]
}

# ==============================================================================
# CLOUDWATCH LOG GROUPS
# ==============================================================================
resource "aws_cloudwatch_log_group" "alerts" {
  count = var.enable_alert_logs ? 1 : 0

  name              = "/aws/networkfirewall/${var.firewall_name}/alerts"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "${var.firewall_name}-alerts"
    LogType = "alerts"
  })
}

resource "aws_cloudwatch_log_group" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/networkfirewall/${var.firewall_name}/flow"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "${var.firewall_name}-flow"
    LogType = "flow"
  })
}

# ==============================================================================
# STATEFUL RULE GROUP – MANAGEMENT BYPASS
# ==============================================================================
resource "aws_networkfirewall_rule_group" "management_bypass" {
  capacity = 100
  name     = "${var.firewall_name}-mgmt-bypass"
  type     = "STATEFUL"

  rule_group {
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }

    rule_variables {
      ip_sets {
        key = "MGMT_SUBNETS"
        ip_set {
          definition = length(var.management_subnet_cidrs) > 0 ? var.management_subnet_cidrs : ["10.255.255.254/32"]
        }
      }

      ip_sets {
        key = "PEER_VPCS"
        ip_set {
          definition = local.peer_cidrs
        }
      }
    }

    rules_source {
      rules_string = <<-EOT
        # Management subnet unrestricted outbound
        pass tcp $MGMT_SUBNETS any -> any any (msg:"Mgmt bypass TCP"; sid:50001; rev:1;)
        pass udp $MGMT_SUBNETS any -> any any (msg:"Mgmt bypass UDP"; sid:50002; rev:1;)
        pass icmp $MGMT_SUBNETS any -> any any (msg:"Mgmt bypass ICMP"; sid:50003; rev:1;)
        
        # Cross-region traffic to/from management
        pass tcp $PEER_VPCS any -> $MGMT_SUBNETS any (msg:"Peer to mgmt TCP"; sid:50010; rev:1;)
        pass udp $PEER_VPCS any -> $MGMT_SUBNETS any (msg:"Peer to mgmt UDP"; sid:50011; rev:1;)
        pass icmp $PEER_VPCS any -> $MGMT_SUBNETS any (msg:"Peer to mgmt ICMP"; sid:50012; rev:1;)
        pass tcp $MGMT_SUBNETS any -> $PEER_VPCS any (msg:"Mgmt to peer TCP"; sid:50013; rev:1;)
        pass udp $MGMT_SUBNETS any -> $PEER_VPCS any (msg:"Mgmt to peer UDP"; sid:50014; rev:1;)
      EOT
    }
  }

  tags = merge(var.tags, {
    Name = "${var.firewall_name}-mgmt-bypass"
  })
}

# ==============================================================================
# STATEFUL RULE GROUP – DOMAIN ALLOWLIST
# ==============================================================================
resource "aws_networkfirewall_rule_group" "domain_allowlist" {
  count = length(var.allowed_domains) > 0 ? 1 : 0

  capacity = 100
  name     = "${var.firewall_name}-domain-allow"
  type     = "STATEFUL"

  rule_group {
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }

    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.allowed_domains
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.firewall_name}-domain-allow"
  })
}

# ==============================================================================
# STATEFUL RULE GROUP – INTER-SUBNET & WORKSPACES
# ==============================================================================
resource "aws_networkfirewall_rule_group" "inter_subnet" {
  capacity = 200
  name     = "${var.firewall_name}-inter-subnet"
  type     = "STATEFUL"

  rule_group {
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }

    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = [var.vpc_cidr]
        }
      }

      ip_sets {
        key = "PRIVATE"
        ip_set {
          definition = length(var.private_subnet_cidrs) > 0 ? var.private_subnet_cidrs : ["10.255.255.253/32"]
        }
      }

      ip_sets {
        key = "MGMT"
        ip_set {
          definition = length(var.management_subnet_cidrs) > 0 ? var.management_subnet_cidrs : ["10.255.255.254/32"]
        }
      }

      ip_sets {
        key = "WORKSPACES"
        ip_set {
          definition = length(local.workspaces_cidrs) > 0 ? local.workspaces_cidrs : ["10.255.255.252/32"]
        }
      }

      ip_sets {
        key = "PEERS"
        ip_set {
          definition = local.peer_cidrs
        }
      }

      ip_sets {
        key = "VPN_CLIENTS"
        ip_set {
          definition = local.vpn_cidrs
        }
      }
    }

    rules_source {
      rules_string = <<-EOT
        # VPC internal traffic
        pass tcp $HOME_NET any -> $HOME_NET any (msg:"VPC TCP"; flow:established; sid:100001; rev:1;)
        pass udp $HOME_NET any -> $HOME_NET any (msg:"VPC UDP"; sid:100002; rev:1;)
        pass icmp $HOME_NET any -> $HOME_NET any (msg:"VPC ICMP"; sid:100003; rev:1;)

        # DNS and NTP
        pass tcp $PRIVATE any -> any 53 (msg:"DNS TCP"; sid:100010; rev:1;)
        pass udp $PRIVATE any -> any 53 (msg:"DNS UDP"; sid:100011; rev:1;)
        pass udp $PRIVATE any -> any 123 (msg:"NTP"; sid:100012; rev:1;)

        # HTTPS/HTTP outbound
        pass tcp $PRIVATE any -> any 443 (msg:"HTTPS"; flow:to_server; sid:100020; rev:1;)
        pass tcp $PRIVATE any -> any 80 (msg:"HTTP"; flow:to_server; sid:100021; rev:1;)

        # AD protocols - local
        pass tcp $PRIVATE any -> $MGMT 88 (msg:"Kerberos TCP"; sid:100100; rev:1;)
        pass udp $PRIVATE any -> $MGMT 88 (msg:"Kerberos UDP"; sid:100101; rev:1;)
        pass tcp $PRIVATE any -> $MGMT 389 (msg:"LDAP TCP"; sid:100110; rev:1;)
        pass udp $PRIVATE any -> $MGMT 389 (msg:"LDAP UDP"; sid:100111; rev:1;)
        pass tcp $PRIVATE any -> $MGMT 636 (msg:"LDAPS"; sid:100120; rev:1;)
        pass tcp $PRIVATE any -> $MGMT 3268:3269 (msg:"GC"; sid:100130; rev:1;)
        pass tcp $PRIVATE any -> $MGMT 445 (msg:"SMB"; sid:100140; rev:1;)
        pass tcp $PRIVATE any -> $MGMT 135 (msg:"RPC"; sid:100150; rev:1;)
        pass tcp $PRIVATE any -> $MGMT 49152:65535 (msg:"RPC Dyn"; sid:100160; rev:1;)
        pass tcp $PRIVATE any -> $MGMT 464 (msg:"Kpasswd TCP"; sid:100170; rev:1;)
        pass udp $PRIVATE any -> $MGMT 464 (msg:"Kpasswd UDP"; sid:100171; rev:1;)

        # AD protocols - cross-region
        pass tcp $PRIVATE any -> $PEERS 88 (msg:"Kerberos TCP peer"; sid:100200; rev:1;)
        pass udp $PRIVATE any -> $PEERS 88 (msg:"Kerberos UDP peer"; sid:100201; rev:1;)
        pass tcp $PRIVATE any -> $PEERS 389 (msg:"LDAP TCP peer"; sid:100210; rev:1;)
        pass udp $PRIVATE any -> $PEERS 389 (msg:"LDAP UDP peer"; sid:100211; rev:1;)
        pass tcp $PRIVATE any -> $PEERS 636 (msg:"LDAPS peer"; sid:100220; rev:1;)
        pass tcp $PRIVATE any -> $PEERS 3268:3269 (msg:"GC peer"; sid:100230; rev:1;)
        pass tcp $PRIVATE any -> $PEERS 445 (msg:"SMB peer"; sid:100240; rev:1;)
        pass tcp $PRIVATE any -> $PEERS 135 (msg:"RPC peer"; sid:100250; rev:1;)
        pass tcp $PRIVATE any -> $PEERS 49152:65535 (msg:"RPC Dyn peer"; sid:100260; rev:1;)

        # WorkSpaces streaming - inbound
        pass tcp any any -> $WORKSPACES 4172 (msg:"PCoIP TCP in"; sid:100400; rev:1;)
        pass udp any any -> $WORKSPACES 4172 (msg:"PCoIP UDP in"; sid:100401; rev:1;)
        pass tcp any any -> $WORKSPACES 4195 (msg:"WSP TCP in"; sid:100402; rev:1;)
        pass udp any any -> $WORKSPACES 4195 (msg:"WSP UDP in"; sid:100403; rev:1;)

        # WorkSpaces streaming - outbound
        pass tcp $WORKSPACES any -> any 4172 (msg:"PCoIP TCP out"; flow:to_server; sid:100410; rev:1;)
        pass udp $WORKSPACES any -> any 4172 (msg:"PCoIP UDP out"; sid:100411; rev:1;)
        pass tcp $WORKSPACES any -> any 4195 (msg:"WSP TCP out"; flow:to_server; sid:100412; rev:1;)
        pass udp $WORKSPACES any -> any 4195 (msg:"WSP UDP out"; sid:100413; rev:1;)

        # ===== VPN CLIENT RULES =====
        # VPN clients to VPC internal traffic
        pass tcp $VPN_CLIENTS any -> $HOME_NET any (msg:"VPN to VPC TCP"; sid:100500; rev:1;)
        pass udp $VPN_CLIENTS any -> $HOME_NET any (msg:"VPN to VPC UDP"; sid:100501; rev:1;)
        pass icmp $VPN_CLIENTS any -> $HOME_NET any (msg:"VPN to VPC ICMP"; sid:100502; rev:1;)

        # VPN clients to management subnets (AD access)
        pass tcp $VPN_CLIENTS any -> $MGMT 88 (msg:"VPN Kerberos TCP"; sid:100510; rev:1;)
        pass udp $VPN_CLIENTS any -> $MGMT 88 (msg:"VPN Kerberos UDP"; sid:100511; rev:1;)
        pass tcp $VPN_CLIENTS any -> $MGMT 389 (msg:"VPN LDAP TCP"; sid:100520; rev:1;)
        pass udp $VPN_CLIENTS any -> $MGMT 389 (msg:"VPN LDAP UDP"; sid:100521; rev:1;)
        pass tcp $VPN_CLIENTS any -> $MGMT 636 (msg:"VPN LDAPS"; sid:100530; rev:1;)
        pass tcp $VPN_CLIENTS any -> $MGMT 3268:3269 (msg:"VPN GC"; sid:100540; rev:1;)
        pass tcp $VPN_CLIENTS any -> $MGMT 445 (msg:"VPN SMB"; sid:100550; rev:1;)
        pass tcp $VPN_CLIENTS any -> $MGMT 135 (msg:"VPN RPC"; sid:100560; rev:1;)
        pass tcp $VPN_CLIENTS any -> $MGMT 49152:65535 (msg:"VPN RPC Dyn"; sid:100570; rev:1;)
        pass tcp $VPN_CLIENTS any -> $MGMT 3389 (msg:"VPN RDP"; sid:100580; rev:1;)
        pass udp $VPN_CLIENTS any -> $MGMT 3389 (msg:"VPN RDP UDP"; sid:100581; rev:1;)

        # VPN clients to private subnets (general access)
        pass tcp $VPN_CLIENTS any -> $PRIVATE 22 (msg:"VPN SSH"; sid:100600; rev:1;)
        pass tcp $VPN_CLIENTS any -> $PRIVATE 3389 (msg:"VPN RDP Private"; sid:100610; rev:1;)
        pass udp $VPN_CLIENTS any -> $PRIVATE 3389 (msg:"VPN RDP UDP Private"; sid:100611; rev:1;)
        pass tcp $VPN_CLIENTS any -> $PRIVATE 443 (msg:"VPN HTTPS Private"; sid:100620; rev:1;)
        pass tcp $VPN_CLIENTS any -> $PRIVATE 80 (msg:"VPN HTTP Private"; sid:100621; rev:1;)

        # VPN clients to peer VPCs (cross-region access)
        pass tcp $VPN_CLIENTS any -> $PEERS any (msg:"VPN to Peer TCP"; sid:100700; rev:1;)
        pass udp $VPN_CLIENTS any -> $PEERS any (msg:"VPN to Peer UDP"; sid:100701; rev:1;)
        pass icmp $VPN_CLIENTS any -> $PEERS any (msg:"VPN to Peer ICMP"; sid:100702; rev:1;)

        # VPN clients DNS and NTP
        pass tcp $VPN_CLIENTS any -> any 53 (msg:"VPN DNS TCP"; sid:100710; rev:1;)
        pass udp $VPN_CLIENTS any -> any 53 (msg:"VPN DNS UDP"; sid:100711; rev:1;)
        pass udp $VPN_CLIENTS any -> any 123 (msg:"VPN NTP"; sid:100712; rev:1;)

        # VPN clients HTTPS/HTTP outbound (for internet access if split-tunnel disabled)
        pass tcp $VPN_CLIENTS any -> any 443 (msg:"VPN HTTPS out"; flow:to_server; sid:100720; rev:1;)
        pass tcp $VPN_CLIENTS any -> any 80 (msg:"VPN HTTP out"; flow:to_server; sid:100721; rev:1;)

        # Drop unmatched
        drop tcp any any -> any any (msg:"Drop TCP"; sid:999998; rev:1;)
        drop udp any any -> any any (msg:"Drop UDP"; sid:999999; rev:1;)
      EOT
    }
  }

  tags = merge(var.tags, {
    Name = "${var.firewall_name}-inter-subnet"
  })
}

# ==============================================================================
# FIREWALL POLICY
# ==============================================================================
resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.firewall_name}-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_default_actions = ["aws:drop_strict"]

    stateful_rule_group_reference {
      priority     = 50
      resource_arn = aws_networkfirewall_rule_group.management_bypass.arn
    }

    dynamic "stateful_rule_group_reference" {
      for_each = length(var.allowed_domains) > 0 ? [1] : []
      content {
        priority     = 100
        resource_arn = aws_networkfirewall_rule_group.domain_allowlist[0].arn
      }
    }

    stateful_rule_group_reference {
      priority     = 200
      resource_arn = aws_networkfirewall_rule_group.inter_subnet.arn
    }
  }

  tags = merge(var.tags, {
    Name = "${var.firewall_name}-policy"
  })
}

# ==============================================================================
# NETWORK FIREWALL
# ==============================================================================
resource "aws_networkfirewall_firewall" "this" {
  name                = var.firewall_name
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = var.vpc_id

  delete_protection                 = var.delete_protection
  firewall_policy_change_protection = false
  subnet_change_protection          = false

  dynamic "subnet_mapping" {
    for_each = var.inspection_subnet_ids
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = merge(var.tags, {
    Name = var.firewall_name
  })
}

# ==============================================================================
# LOGGING CONFIGURATION
# ==============================================================================
resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    dynamic "log_destination_config" {
      for_each = var.enable_alert_logs ? [1] : []
      content {
        log_destination = {
          logGroup = aws_cloudwatch_log_group.alerts[0].name
        }
        log_destination_type = "CloudWatchLogs"
        log_type             = "ALERT"
      }
    }

    dynamic "log_destination_config" {
      for_each = var.enable_flow_logs ? [1] : []
      content {
        log_destination = {
          logGroup = aws_cloudwatch_log_group.flow[0].name
        }
        log_destination_type = "CloudWatchLogs"
        log_type             = "FLOW"
      }
    }
  }
}

# ==============================================================================
# OUTPUTS
# ==============================================================================
locals {
  firewall_endpoints = [
    for state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.attachment[0].endpoint_id
  ]
}

output "firewall_id" {
  description = "ID of the Network Firewall"
  value       = aws_networkfirewall_firewall.this.id
}

output "firewall_arn" {
  description = "ARN of the Network Firewall"
  value       = aws_networkfirewall_firewall.this.arn
}

output "firewall_endpoint_ids" {
  description = "IDs of the firewall endpoints"
  value       = local.firewall_endpoints
}

output "firewall_policy_arn" {
  description = "ARN of the firewall policy"
  value       = aws_networkfirewall_firewall_policy.this.arn
}
