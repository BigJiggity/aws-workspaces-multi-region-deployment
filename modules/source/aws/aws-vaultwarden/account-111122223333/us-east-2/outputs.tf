# ==============================================================================
# OUTPUTS
# ==============================================================================

# ------------------------------------------------------------------------------
# ALB / DNS CONFIGURATION
# ------------------------------------------------------------------------------
output "alb_dns_name" {
  description = "ALB DNS name - Create CNAME record pointing vw.example.com to this"
  value       = aws_lb.vaultwarden.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID (for Route53 Alias records)"
  value       = aws_lb.vaultwarden.zone_id
}

output "acm_certificate_validation_records" {
  description = "DNS records to create for ACM certificate validation (only if using ACM-issued cert)"
  value = var.use_imported_certificate ? {} : {
    for dvo in aws_acm_certificate.vaultwarden[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}

output "certificate_arn" {
  description = "ACM certificate ARN in use"
  value       = local.certificate_arn
}

output "fqdn" {
  description = "VaultWarden FQDN"
  value       = var.fqdn
}

output "vaultwarden_url" {
  description = "VaultWarden URL"
  value       = "https://${var.fqdn}"
}

output "admin_panel_url" {
  description = "VaultWarden admin panel URL"
  value       = var.enable_admin_panel ? "https://${var.fqdn}/admin" : null
}

# ------------------------------------------------------------------------------
# ECS
# ------------------------------------------------------------------------------
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.vaultwarden.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.vaultwarden.arn
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.vaultwarden.name
}

# ------------------------------------------------------------------------------
# ECR
# ------------------------------------------------------------------------------
output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.vaultwarden.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.vaultwarden.arn
}

# ------------------------------------------------------------------------------
# RDS
# ------------------------------------------------------------------------------
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.vaultwarden.endpoint
}

output "rds_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.vaultwarden.identifier
}

# ------------------------------------------------------------------------------
# SECRETS
# ------------------------------------------------------------------------------
output "admin_token_secret_arn" {
  description = "Secrets Manager ARN for admin token"
  value       = aws_secretsmanager_secret.admin_token.arn
}

output "db_credentials_secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

# ------------------------------------------------------------------------------
# WAF
# ------------------------------------------------------------------------------
output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.vaultwarden.arn
}

# ------------------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------------------
output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

# ------------------------------------------------------------------------------
# CLOUDWATCH
# ------------------------------------------------------------------------------
output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.vaultwarden.dashboard_name}"
}

output "ecs_log_group" {
  description = "ECS CloudWatch log group name"
  value       = aws_cloudwatch_log_group.ecs.name
}

# ------------------------------------------------------------------------------
# INSTRUCTIONS
# ------------------------------------------------------------------------------
output "dns_configuration_instructions" {
  description = "Instructions for DNS configuration"
  value       = <<-EOF

    ============================================================================
    DNS CONFIGURATION REQUIRED
    ============================================================================

    ${var.use_imported_certificate ? "1. CERTIFICATE ALREADY IMPORTED\n       Using imported certificate: ${var.imported_certificate_arn}" : "1. ACM CERTIFICATE VALIDATION\n       Create the following DNS record to validate the ACM certificate:\n       ${join("\n       ", [for dvo in aws_acm_certificate.vaultwarden[0].domain_validation_options : "${dvo.resource_record_name} ${dvo.resource_record_type} ${dvo.resource_record_value}"])}"}

    2. APPLICATION DNS RECORD
       Create a CNAME record:
       
       Name:  vw.example.com
       Type:  CNAME
       Value: ${aws_lb.vaultwarden.dns_name}

    3. VERIFY DEPLOYMENT
       After DNS propagation, access: https://vw.example.com

    4. ADMIN PANEL
       ${var.enable_admin_panel ? "Access admin panel at: https://vw.example.com/admin\n       Retrieve admin token: aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.admin_token.name} --query SecretString --output text" : "Admin panel is disabled"}

    ============================================================================
  EOF
}

output "image_push_instructions" {
  description = "Instructions to push VaultWarden image to ECR"
  value       = <<-EOF

    ============================================================================
    IMAGE PUSH INSTRUCTIONS
    ============================================================================

    If the null_resource.push_image failed, manually push the image:

    # Login to ECR
    aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com

    # Pull from Docker Hub
    docker pull vaultwarden/server:${var.container_image_tag}

    # Tag for ECR
    docker tag vaultwarden/server:${var.container_image_tag} ${aws_ecr_repository.vaultwarden.repository_url}:${var.container_image_tag}

    # Push to ECR
    docker push ${aws_ecr_repository.vaultwarden.repository_url}:${var.container_image_tag}

    ============================================================================
  EOF
}
