#!/bin/bash
# ==============================================================================
# US-EAST-2 TERRAFORM IMPORT SCRIPT
# Imports existing infrastructure into Terraform state
# Compatible with macOS bash 3.x
# ==============================================================================

set -e

REGION="us-east-2"
TF_DIR="$(dirname "$0")/../../us-east-2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}US-EAST-2 Import Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Change to terraform directory
cd "$TF_DIR"
echo -e "${YELLOW}Working directory: $(pwd)${NC}"

# Initialize terraform if needed
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init
fi

# ==============================================================================
# GATHER RESOURCE IDS
# ==============================================================================
echo -e "\n${GREEN}Gathering resource IDs from AWS...${NC}"

# VPC - find by existing DC instances
echo "Finding VPC..."
VPC_ID=$(aws ec2 describe-instances --region $REGION \
    --instance-ids i-0e5f7fdd4219cc530 \
    --query 'Reservations[0].Instances[0].VpcId' --output text)
echo "  VPC_ID: $VPC_ID"

# Internet Gateway
echo "Finding Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --region $REGION \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' --output text)
echo "  IGW_ID: $IGW_ID"

# Transit Gateway - known existing
TGW_ID="tgw-0dcbbab20d066677a"
echo "  TGW_ID: $TGW_ID"

# TGW Route Table
TGW_RTB=$(aws ec2 describe-transit-gateway-route-tables --region $REGION \
    --filters "Name=transit-gateway-id,Values=$TGW_ID" \
    --query 'TransitGatewayRouteTables[0].TransitGatewayRouteTableId' --output text)
echo "  TGW_RTB: $TGW_RTB"

# TGW VPC Attachment
TGW_VPC_ATTACH=$(aws ec2 describe-transit-gateway-vpc-attachments --region $REGION \
    --filters "Name=transit-gateway-id,Values=$TGW_ID" "Name=vpc-id,Values=$VPC_ID" \
    --query 'TransitGatewayVpcAttachments[0].TransitGatewayAttachmentId' --output text)
echo "  TGW_VPC_ATTACH: $TGW_VPC_ATTACH"

# Network Firewall
echo "Finding Network Firewall..."
FW_NAME=$(aws network-firewall list-firewalls --region $REGION \
    --vpc-ids $VPC_ID \
    --query 'Firewalls[0].FirewallName' --output text)
echo "  FW_NAME: $FW_NAME"

FW_ARN=""
FW_POLICY_ARN=""
if [ "$FW_NAME" != "None" ] && [ -n "$FW_NAME" ]; then
    FW_ARN=$(aws network-firewall describe-firewall --region $REGION \
        --firewall-name "$FW_NAME" \
        --query 'Firewall.FirewallArn' --output text 2>/dev/null || echo "")
    echo "  FW_ARN: $FW_ARN"

    FW_POLICY_ARN=$(aws network-firewall describe-firewall --region $REGION \
        --firewall-name "$FW_NAME" \
        --query 'Firewall.FirewallPolicyArn' --output text 2>/dev/null || echo "")
    echo "  FW_POLICY_ARN: $FW_POLICY_ARN"
fi

# ==============================================================================
# TERRAFORM IMPORTS
# ==============================================================================
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}Starting Terraform Imports${NC}"
echo -e "${YELLOW}========================================${NC}"

# Function to safely import
import_resource() {
    local address=$1
    local id=$2
    
    if [ -z "$id" ] || [ "$id" == "None" ] || [ "$id" == "null" ]; then
        echo -e "${YELLOW}SKIP: $address (no ID found)${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Importing: $address = $id${NC}"
    if terraform import "$address" "$id" 2>&1; then
        echo -e "${GREEN}SUCCESS: $address${NC}"
    else
        echo -e "${RED}FAILED: $address (may already exist in state)${NC}"
    fi
}

# Import VPC
import_resource "module.vpc.aws_vpc.this" "$VPC_ID"

# Import IGW
import_resource "module.vpc.aws_internet_gateway.this" "$IGW_ID"

# Import Subnets
echo -e "\n${GREEN}Importing Subnets...${NC}"

# Public subnets (10.0.0.0/24, 10.0.1.0/24)
i=0
for subnet_id in $(aws ec2 describe-subnets --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[?CidrBlock==`10.0.0.0/24` || CidrBlock==`10.0.1.0/24`].SubnetId' --output text | tr '\t' '\n' | sort); do
    import_resource "module.subnets.aws_subnet.public[$i]" "$subnet_id"
    i=$((i+1))
done

# Private subnets (10.0.10.0/24, 10.0.11.0/24)
i=0
for subnet_id in $(aws ec2 describe-subnets --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[?CidrBlock==`10.0.10.0/24` || CidrBlock==`10.0.11.0/24`].SubnetId' --output text | tr '\t' '\n' | sort); do
    import_resource "module.subnets.aws_subnet.private[$i]" "$subnet_id"
    i=$((i+1))
done

# Management subnets (10.0.12.0/24, 10.0.13.0/24, 10.0.14.0/24)
i=0
for subnet_id in $(aws ec2 describe-subnets --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[?CidrBlock==`10.0.12.0/24` || CidrBlock==`10.0.13.0/24` || CidrBlock==`10.0.14.0/24`].SubnetId' --output text | tr '\t' '\n' | sort); do
    import_resource "module.subnets.aws_subnet.management[$i]" "$subnet_id"
    i=$((i+1))
done

# Inspection subnets (10.0.100.0/28, 10.0.100.16/28)
i=0
for subnet_id in $(aws ec2 describe-subnets --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[?CidrBlock==`10.0.100.0/28` || CidrBlock==`10.0.100.16/28`].SubnetId' --output text | tr '\t' '\n' | sort); do
    import_resource "module.subnets.aws_subnet.inspection[$i]" "$subnet_id"
    i=$((i+1))
done

# TGW Attachment subnets (10.0.200.0/28, 10.0.200.16/28)
i=0
for subnet_id in $(aws ec2 describe-subnets --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[?CidrBlock==`10.0.200.0/28` || CidrBlock==`10.0.200.16/28`].SubnetId' --output text | tr '\t' '\n' | sort); do
    import_resource "module.subnets.aws_subnet.tgw_attachment[$i]" "$subnet_id"
    i=$((i+1))
done

# Import Transit Gateway
echo -e "\n${GREEN}Importing Transit Gateway...${NC}"
import_resource "module.transit_gateway.aws_ec2_transit_gateway.this" "$TGW_ID"
import_resource "module.transit_gateway.aws_ec2_transit_gateway_vpc_attachment.this" "$TGW_VPC_ATTACH"

# Import Network Firewall
echo -e "\n${GREEN}Importing Network Firewall...${NC}"
if [ -n "$FW_ARN" ] && [ "$FW_ARN" != "None" ]; then
    import_resource "module.network_firewall.aws_networkfirewall_firewall.this" "$FW_ARN"
    import_resource "module.network_firewall.aws_networkfirewall_firewall_policy.this" "$FW_POLICY_ARN"
fi

# Import Route Tables
echo -e "\n${GREEN}Importing Route Tables...${NC}"

# Get first public subnet for route table lookup
FIRST_PUBLIC=$(aws ec2 describe-subnets --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[?CidrBlock==`10.0.0.0/24`].SubnetId' --output text)

if [ -n "$FIRST_PUBLIC" ] && [ "$FIRST_PUBLIC" != "None" ]; then
    PUBLIC_RTB=$(aws ec2 describe-route-tables --region $REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.subnet-id,Values=$FIRST_PUBLIC" \
        --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || echo "")
    import_resource "module.subnets.aws_route_table.public[0]" "$PUBLIC_RTB"
fi

# NAT Gateways
echo -e "\n${GREEN}Importing NAT Gateways...${NC}"
i=0
for nat_id in $(aws ec2 describe-nat-gateways --region $REGION \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --query 'NatGateways[].NatGatewayId' --output text | tr '\t' '\n'); do
    import_resource "module.subnets.aws_nat_gateway.this[$i]" "$nat_id"
    i=$((i+1))
done

# EIPs
echo -e "\n${GREEN}Importing Elastic IPs...${NC}"
i=0
for eip_id in $(aws ec2 describe-nat-gateways --region $REGION \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --query 'NatGateways[].NatGatewayAddresses[0].AllocationId' --output text | tr '\t' '\n'); do
    import_resource "module.subnets.aws_eip.nat[$i]" "$eip_id"
    i=$((i+1))
done

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}US-EAST-2 Import Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Run 'terraform plan' to see any drift"
echo -e "  2. Adjust configuration as needed"
echo -e "  3. Run 'terraform apply' to reconcile state"
