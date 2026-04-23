# ==============================================================================
# OUTPUTS
# Project: account-111122223333
# Export values for org-workspaces-vdi and other dependent projects
# ==============================================================================

# ------------------------------------------------------------------------------
# DOMAIN CONTROLLER IPs
# ------------------------------------------------------------------------------
output "dc01_private_ip" {
  description = "Private IP of DC01 (Primary DC, us-east-2a)"
  value       = aws_instance.dc01.private_ip
}

output "dc02_private_ip" {
  description = "Private IP of DC02 (Secondary DC, us-east-1a)"
  value       = aws_instance.dc02.private_ip
}

output "dc03_private_ip" {
  description = "Private IP of DC03 (Replica DC, ap-southeast-1a)"
  value       = aws_instance.dc03.private_ip
}

output "dc_ips_use2" {
  description = "List of DC IPs in us-east-2"
  value       = [aws_instance.dc01.private_ip]
}

output "dc_ips_use1" {
  description = "List of DC IPs in us-east-1"
  value       = [aws_instance.dc02.private_ip]
}

output "dc_ips_apse1" {
  description = "List of DC IPs in ap-southeast-1"
  value       = [aws_instance.dc03.private_ip]
}

output "all_dc_ips" {
  description = "List of all DC IPs across regions"
  value       = [aws_instance.dc01.private_ip, aws_instance.dc02.private_ip, aws_instance.dc03.private_ip]
}

# ------------------------------------------------------------------------------
# INSTANCE IDs
# ------------------------------------------------------------------------------
output "dc01_instance_id" {
  description = "Instance ID of DC01"
  value       = aws_instance.dc01.id
}

output "dc02_instance_id" {
  description = "Instance ID of DC02"
  value       = aws_instance.dc02.id
}

output "dc03_instance_id" {
  description = "Instance ID of DC03"
  value       = aws_instance.dc03.id
}

# ------------------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------------------
output "dc_security_group_use2" {
  description = "Security group ID for DCs in us-east-2"
  value       = aws_security_group.dc_use2.id
}

output "dc_security_group_use1" {
  description = "Security group ID for DCs in us-east-1"
  value       = aws_security_group.dc_use1.id
}

output "dc_security_group_apse1" {
  description = "Security group ID for DCs in ap-southeast-1"
  value       = aws_security_group.dc_apse1.id
}

# ------------------------------------------------------------------------------
# ROUTE53
# ------------------------------------------------------------------------------
output "route53_zone_id" {
  description = "Route53 private hosted zone ID for example.internal"
  value       = aws_route53_zone.org_int.zone_id
}

output "route53_zone_name" {
  description = "Route53 private hosted zone name"
  value       = aws_route53_zone.org_int.name
}

output "resolver_rule_use2_id" {
  description = "Route53 Resolver rule ID for us-east-2"
  value       = aws_route53_resolver_rule.org_int_forward.id
}

output "resolver_rule_use1_id" {
  description = "Route53 Resolver rule ID for us-east-1"
  value       = aws_route53_resolver_rule.org_int_forward_use1.id
}

output "resolver_rule_apse1_id" {
  description = "Route53 Resolver rule ID for ap-southeast-1"
  value       = aws_route53_resolver_rule.org_int_forward_apse1.id
}

# ------------------------------------------------------------------------------
# ACTIVE DIRECTORY
# ------------------------------------------------------------------------------
output "ad_domain_name" {
  description = "AD domain name"
  value       = var.ad_domain_name
}

output "ad_netbios_name" {
  description = "AD NetBIOS name"
  value       = var.ad_netbios_name
}

output "ad_secrets_arn" {
  description = "ARN of Secrets Manager secret containing AD passwords"
  value       = aws_secretsmanager_secret.ad_passwords.arn
}

# ------------------------------------------------------------------------------
# DNS IPs FOR AD CONNECTOR
# These are the IPs to use when configuring AD Connector
# ------------------------------------------------------------------------------
output "dns_ips_for_ad_connector" {
  description = "DNS IPs to use for AD Connector (DC03 + DC01 for ap-southeast-1)"
  value       = [aws_instance.dc03.private_ip, aws_instance.dc01.private_ip]
}

output "dns_ips_for_ad_connector_use1" {
  description = "DNS IPs to use for AD Connector in us-east-1 (DC02 local + DC01 fallback)"
  value       = [aws_instance.dc02.private_ip, aws_instance.dc01.private_ip]
}

# ------------------------------------------------------------------------------
# KEY PAIR
# ------------------------------------------------------------------------------
output "key_pair_name_use2" {
  description = "Key pair name for DCs in us-east-2"
  value       = local.use2_key_name
}

output "key_pair_name_use1" {
  description = "Key pair name for DCs in us-east-1"
  value       = local.use1_key_name
}

output "key_pair_name_apse1" {
  description = "Key pair name for DCs in ap-southeast-1"
  value       = local.apse1_key_name
}

output "private_key_secret_arn" {
  description = "ARN of Secrets Manager secret containing the private key"
  value       = var.key_pair_name == "" ? aws_secretsmanager_secret.dc_private_key[0].arn : null
}
