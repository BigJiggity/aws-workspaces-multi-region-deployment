# ==============================================================================
# MODULE OUTPUTS: VPC-US-EAST-2
# Exposes VPC resource identifiers for use by other modules
# ==============================================================================

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.this.arn
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "management_subnet_ids" {
  description = "List of management (private) subnet IDs for Managed AD deployment"
  value       = aws_subnet.management[*].id
}

output "management_subnet_cidrs" {
  description = "List of management subnet CIDR blocks"
  value       = aws_subnet.management[*].cidr_block
}

output "availability_zones" {
  description = "List of availability zones used for subnet deployment"
  value       = local.azs
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.this.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "all_route_table_ids" {
  description = "List of all route table IDs (for VPC peering route propagation)"
  value       = [aws_route_table.public.id, aws_route_table.private.id]
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch log group for VPC flow logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}
