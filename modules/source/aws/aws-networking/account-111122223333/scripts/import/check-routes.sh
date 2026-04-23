#!/bin/bash
# ==============================================================================
# Check current state of route tables and associations
# ==============================================================================

REGION="us-east-2"
VPC_ID="vpc-066b5d5ade267680f"

echo "=== ALL ROUTE TABLES IN VPC ==="
aws ec2 describe-route-tables --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Name`].Value|[0]]' \
    --output table

echo ""
echo "=== SUBNET ASSOCIATIONS ==="
aws ec2 describe-route-tables --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[*].{RT:RouteTableId,Name:Tags[?Key==`Name`].Value|[0],Assocs:Associations[*].{SubnetId:SubnetId,AssocId:RouteTableAssociationId,Main:Main}}' \
    --output json | jq -r '.[] | "RT: \(.RT) (\(.Name // "unnamed"))\n  Associations: \(.Assocs | map(select(.SubnetId != null)) | map("    \(.SubnetId) -> \(.AssocId)") | join("\n"))"'

echo ""
echo "=== TERRAFORM STATE ROUTE TABLES ==="
cd ~/Repos/cloud_infrastructure/org-aws-networking/account-111122223333/us-east-2
terraform state list 2>/dev/null | grep "route_table" | head -30
