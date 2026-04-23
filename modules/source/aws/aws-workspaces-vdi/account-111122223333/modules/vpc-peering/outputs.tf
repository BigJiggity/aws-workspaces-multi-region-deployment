# ==============================================================================
# MODULE OUTPUTS: VPC-PEERING
# ==============================================================================

output "peering_connection_id" {
  description = "ID of the VPC peering connection"
  value       = aws_vpc_peering_connection.this.id
}

output "peering_status" {
  description = "Status of the VPC peering connection"
  value       = aws_vpc_peering_connection_accepter.this.accept_status
}

output "requester_region" {
  description = "Region of the requester VPC"
  value       = data.aws_region.requester.id
}

output "accepter_region" {
  description = "Region of the accepter VPC"
  value       = data.aws_region.accepter.id
}
