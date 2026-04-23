# ==============================================================================
# MODULE OUTPUTS: TRANSIT-GATEWAY-PEERING
# ==============================================================================

output "peering_attachment_id" {
  description = "ID of the Transit Gateway peering attachment"
  value       = aws_ec2_transit_gateway_peering_attachment.this.id
}

output "peering_attachment_state" {
  description = "State of the Transit Gateway peering attachment"
  value       = aws_ec2_transit_gateway_peering_attachment.this.id
}

output "requester_region" {
  description = "Region of the requester Transit Gateway"
  value       = var.requester_region
}

output "accepter_region" {
  description = "Region of the accepter Transit Gateway"
  value       = var.accepter_region
}

output "requester_tgw_id" {
  description = "Transit Gateway ID in requester region"
  value       = var.requester_tgw_id
}

output "accepter_tgw_id" {
  description = "Transit Gateway ID in accepter region"
  value       = var.accepter_tgw_id
}
