# ==============================================================================
# ROOT OUTPUTS – Generic SSM VPC Endpoints
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC ENDPOINT IDs
# ------------------------------------------------------------------------------
output "ssm_endpoint_id" {
  description = "ID of the SSM VPC endpoint"
  value       = aws_vpc_endpoint.ssm.id
}

output "ssmmessages_endpoint_id" {
  description = "ID of the SSM Messages VPC endpoint"
  value       = aws_vpc_endpoint.ssmmessages.id
}

output "ec2messages_endpoint_id" {
  description = "ID of the EC2 Messages VPC endpoint"
  value       = aws_vpc_endpoint.ec2messages.id
}

output "endpoint_ids" {
  description = "Map of all SSM endpoint IDs"
  value = {
    ssm         = aws_vpc_endpoint.ssm.id
    ssmmessages = aws_vpc_endpoint.ssmmessages.id
    ec2messages = aws_vpc_endpoint.ec2messages.id
  }
}

# ------------------------------------------------------------------------------
# VPC ENDPOINT DNS ENTRIES
# ------------------------------------------------------------------------------
output "ssm_endpoint_dns" {
  description = "DNS entries for SSM endpoint"
  value       = aws_vpc_endpoint.ssm.dns_entry
}

output "ssmmessages_endpoint_dns" {
  description = "DNS entries for SSM Messages endpoint"
  value       = aws_vpc_endpoint.ssmmessages.dns_entry
}

output "ec2messages_endpoint_dns" {
  description = "DNS entries for EC2 Messages endpoint"
  value       = aws_vpc_endpoint.ec2messages.dns_entry
}

# ------------------------------------------------------------------------------
# SECURITY GROUP
# ------------------------------------------------------------------------------
output "security_group_id" {
  description = "ID of the security group for SSM endpoints"
  value       = aws_security_group.ssm_endpoints.id
}

output "security_group_arn" {
  description = "ARN of the security group for SSM endpoints"
  value       = aws_security_group.ssm_endpoints.arn
}

# ------------------------------------------------------------------------------
# NETWORK INFORMATION (FROM REMOTE STATE)
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID where endpoints are deployed"
  value       = local.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = local.vpc_cidr
}

output "subnet_ids" {
  description = "Subnet IDs where endpoints are deployed"
  value       = local.management_subnets
}

# ------------------------------------------------------------------------------
# SUMMARY OUTPUT
# ------------------------------------------------------------------------------
output "infrastructure_summary" {
  description = "Summary of deployed SSM endpoint infrastructure"
  value = {
    vpc_id            = local.vpc_id
    vpc_cidr          = local.vpc_cidr
    region            = var.aws_region
    subnet_count      = length(local.management_subnets)
    security_group_id = aws_security_group.ssm_endpoints.id
    endpoints = {
      ssm         = aws_vpc_endpoint.ssm.id
      ssmmessages = aws_vpc_endpoint.ssmmessages.id
      ec2messages = aws_vpc_endpoint.ec2messages.id
    }
  }
}
