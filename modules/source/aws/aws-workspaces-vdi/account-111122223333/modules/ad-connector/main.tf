# ==============================================================================
# MODULE: AD-CONNECTOR
# Creates AD Connector in ap-southeast-1 to connect WorkSpaces to AD Replica
#
# Why AD Connector?
# AWS WorkSpaces directory registration can ONLY occur in a directory's PRIMARY
# region. Since our Managed AD primary is in us-east-2 and ap-southeast-1 has
# a replica, we cannot directly register WorkSpaces against the replica.
#
# The solution is to create an AD Connector in ap-southeast-1 that points to
# the AD Replica's DNS IPs. WorkSpaces can then be registered against the
# AD Connector, enabling WorkSpaces in Manila Local Zone while authenticating
# against the low-latency AD Replica.
# ==============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ------------------------------------------------------------------------------
# VARIABLES
# ------------------------------------------------------------------------------
variable "connector_name" {
  description = "Name for the AD Connector"
  type        = string
  default     = "org-ad-connector"
}

variable "domain_name" {
  description = "Fully qualified domain name of the AD (e.g., corp.example.internal)"
  type        = string
}

variable "dns_ips" {
  description = "DNS IP addresses of the AD Replica domain controllers"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID where AD Connector will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for AD Connector (must be in 2 different AZs)"
  type        = list(string)
}

variable "connector_size" {
  description = "Size of AD Connector (Small or Large)"
  type        = string
  default     = "Small"

  validation {
    condition     = contains(["Small", "Large"], var.connector_size)
    error_message = "Connector size must be Small or Large."
  }
}

variable "service_account_username" {
  description = "Username of service account with permissions to join computers to domain"
  type        = string
}

variable "service_account_password" {
  description = "Password for service account (will be stored in Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# SECRETS MANAGER: AD CONNECTOR SERVICE ACCOUNT PASSWORD
# Stores the service account password securely
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "ad_connector_password" {
  name        = "${var.connector_name}-service-account-password"
  description = "Service account password for AD Connector ${var.connector_name}"

  tags = merge(var.tags, {
    Name = "${var.connector_name}-service-account-password"
  })
}

resource "aws_secretsmanager_secret_version" "ad_connector_password" {
  secret_id     = aws_secretsmanager_secret.ad_connector_password.id
  secret_string = var.service_account_password
}

# ------------------------------------------------------------------------------
# AD CONNECTOR
# Connects to AD Replica domain controllers for WorkSpaces authentication
# ------------------------------------------------------------------------------
resource "aws_directory_service_directory" "connector" {
  name = var.domain_name
  type = "ADConnector"
  size = var.connector_size

  connect_settings {
    vpc_id            = var.vpc_id
    subnet_ids        = length(var.subnet_ids) >= 2 ? slice(var.subnet_ids, 0, 2) : var.subnet_ids
    customer_dns_ips  = var.dns_ips
    customer_username = var.service_account_username
  }

  password = var.service_account_password

  tags = merge(var.tags, {
    Name        = var.connector_name
    Description = "AD Connector for WorkSpaces - connects to AD Replica"
  })
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------
output "connector_id" {
  description = "ID of the AD Connector"
  value       = aws_directory_service_directory.connector.id
}

output "connector_dns_ips" {
  description = "DNS IP addresses assigned to the AD Connector"
  value       = aws_directory_service_directory.connector.dns_ip_addresses
}

output "dns_ip_addresses" {
  description = "DNS IP addresses assigned to the AD Connector (alias)"
  value       = aws_directory_service_directory.connector.dns_ip_addresses
}

output "connector_security_group_id" {
  description = "Security group ID created for the AD Connector"
  value       = aws_directory_service_directory.connector.security_group_id
}
