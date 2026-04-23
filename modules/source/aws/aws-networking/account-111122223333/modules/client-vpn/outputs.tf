# ==============================================================================
# CLIENT VPN MODULE - OUTPUTS
# ==============================================================================

output "vpn_endpoint_id" {
  description = "Client VPN endpoint ID"
  value       = aws_ec2_client_vpn_endpoint.this.id
}

output "vpn_endpoint_arn" {
  description = "Client VPN endpoint ARN"
  value       = aws_ec2_client_vpn_endpoint.this.arn
}

output "vpn_endpoint_dns_name" {
  description = "DNS name for VPN client connection"
  value       = aws_ec2_client_vpn_endpoint.this.dns_name
}

output "vpn_subnet_ids" {
  description = "VPN subnet IDs"
  value       = aws_subnet.vpn[*].id
}

output "vpn_route_table_id" {
  description = "VPN route table ID"
  value       = aws_route_table.vpn.id
}

output "vpn_security_group_id" {
  description = "VPN security group ID"
  value       = aws_security_group.vpn.id
}

output "vpn_log_group_name" {
  description = "CloudWatch log group for VPN connections"
  value       = aws_cloudwatch_log_group.vpn.name
}

output "server_certificate_arn" {
  description = "Server certificate ARN in ACM"
  value       = aws_acm_certificate.server.arn
}

output "client_certificate_arn" {
  description = "Client certificate ARN in ACM"
  value       = aws_acm_certificate.client.arn
}

output "client_credentials_secret_arn" {
  description = "Secrets Manager ARN containing client credentials"
  value       = aws_secretsmanager_secret.vpn_client_config.arn
}

output "client_credentials_secret_name" {
  description = "Secrets Manager name containing client credentials"
  value       = aws_secretsmanager_secret.vpn_client_config.name
}

# Output the OVPN config template
output "client_configuration_instructions" {
  description = "Instructions for generating client configuration"
  value       = <<-EOT
    
    ============================================================
    CLIENT VPN CONFIGURATION INSTRUCTIONS
    ============================================================
    
    1. Download the client configuration file:
       aws ec2 export-client-vpn-client-configuration \
         --client-vpn-endpoint-id ${aws_ec2_client_vpn_endpoint.this.id} \
         --output text > client-config.ovpn
    
    2. Retrieve client credentials from Secrets Manager:
       aws secretsmanager get-secret-value \
         --secret-id ${aws_secretsmanager_secret.vpn_client_config.name} \
         --query SecretString --output text | jq -r '.client_certificate' > client.crt
       
       aws secretsmanager get-secret-value \
         --secret-id ${aws_secretsmanager_secret.vpn_client_config.name} \
         --query SecretString --output text | jq -r '.client_private_key' > client.key
    
    3. Add the following to client-config.ovpn before </ca>:
       
       <cert>
       [contents of client.crt]
       </cert>
       
       <key>
       [contents of client.key]
       </key>
    
    4. Import into AWS VPN Client or OpenVPN client.
    
    VPN Endpoint DNS: ${aws_ec2_client_vpn_endpoint.this.dns_name}
    Client CIDR: ${var.vpn_client_cidr}
    
    ============================================================
  EOT
}
