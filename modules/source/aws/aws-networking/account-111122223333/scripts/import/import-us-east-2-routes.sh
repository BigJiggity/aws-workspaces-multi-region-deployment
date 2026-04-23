#!/bin/bash
# ==============================================================================
# US-EAST-2 ROUTE TABLE ASSOCIATIONS & ROUTES IMPORT SCRIPT
# Imports existing route table associations and routes into Terraform state
# ==============================================================================

set -e

REGION="us-east-2"
TF_DIR="$(dirname "$0")/../../us-east-2"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}US-EAST-2 Route Tables Import${NC}"
echo -e "${GREEN}========================================${NC}"

cd "$TF_DIR"
echo -e "${YELLOW}Working directory: $(pwd)${NC}"

# VPC ID
VPC_ID="vpc-066b5d5ade267680f"
PUBLIC_RT_ID="rtb-0a67abc53eec50633"

# ==============================================================================
# IMPORT EXISTING ROUTE TABLES
# ==============================================================================
echo -e "\n${GREEN}Finding existing route tables...${NC}"

# Get all route tables in VPC
echo "Querying route tables..."
ROUTE_TABLES=$(aws ec2 describe-route-tables --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Name`].Value|[0],Tags[?Key==`Tier`].Value|[0]]' \
    --output text)

echo "Route tables found:"
echo "$ROUTE_TABLES"

# ==============================================================================
# IMPORT ROUTE TABLE ASSOCIATIONS
# ==============================================================================
echo -e "\n${GREEN}Finding and importing route table associations...${NC}"

# Subnet IDs we need to find associations for
INSPECTION_SUBNETS=("subnet-04bf0f879377681ad" "subnet-0c413fecab423a4ff")
TGW_SUBNETS=("subnet-085543e519c1bead4" "subnet-036d2a3af5f2a8832")
PRIVATE_SUBNETS=("subnet-007b741225dc6acf8" "subnet-03aa35eff2949941e")
MANAGEMENT_SUBNETS=("subnet-0a7442960deb174d8" "subnet-0cc704fdbd559db03" "subnet-0750672f34aa1d123")
PUBLIC_SUBNETS=("subnet-07ae679ec03e61490" "subnet-098bdd5938edb0833")

# Function to get association ID for a subnet
get_association() {
    local subnet_id=$1
    aws ec2 describe-route-tables --region $REGION \
        --query "RouteTables[*].Associations[?SubnetId=='$subnet_id'].[RouteTableAssociationId,RouteTableId]" \
        --output text | grep -v "^$" | head -1
}

# Import inspection subnet associations
echo -e "\n${YELLOW}Importing inspection subnet associations...${NC}"
for i in 0 1; do
    SUBNET_ID="${INSPECTION_SUBNETS[$i]}"
    RESULT=$(get_association "$SUBNET_ID")
    if [ -n "$RESULT" ]; then
        ASSOC_ID=$(echo "$RESULT" | awk '{print $1}')
        RT_ID=$(echo "$RESULT" | awk '{print $2}')
        echo "  Inspection[$i]: $SUBNET_ID -> RT $RT_ID (assoc: $ASSOC_ID)"
        
        # Import route table first if not the public one
        if [ "$RT_ID" != "$PUBLIC_RT_ID" ]; then
            echo "    Importing route table $RT_ID..."
            terraform import "module.subnets.aws_route_table.inspection[$i]" "$RT_ID" 2>/dev/null || echo "    (already imported or error)"
        fi
        
        # Import association
        echo "    Importing association..."
        terraform import "module.subnets.aws_route_table_association.inspection[$i]" "$ASSOC_ID" 2>/dev/null || echo "    (already imported or error)"
    else
        echo "  No association found for inspection[$i]: $SUBNET_ID"
    fi
done

# Import TGW subnet associations
echo -e "\n${YELLOW}Importing TGW attachment subnet associations...${NC}"
for i in 0 1; do
    SUBNET_ID="${TGW_SUBNETS[$i]}"
    RESULT=$(get_association "$SUBNET_ID")
    if [ -n "$RESULT" ]; then
        ASSOC_ID=$(echo "$RESULT" | awk '{print $1}')
        RT_ID=$(echo "$RESULT" | awk '{print $2}')
        echo "  TGW[$i]: $SUBNET_ID -> RT $RT_ID (assoc: $ASSOC_ID)"
        
        if [ "$RT_ID" != "$PUBLIC_RT_ID" ]; then
            echo "    Importing route table $RT_ID..."
            terraform import "module.subnets.aws_route_table.tgw_attachment[$i]" "$RT_ID" 2>/dev/null || echo "    (already imported or error)"
        fi
        
        echo "    Importing association..."
        terraform import "module.subnets.aws_route_table_association.tgw_attachment[$i]" "$ASSOC_ID" 2>/dev/null || echo "    (already imported or error)"
    else
        echo "  No association found for TGW[$i]: $SUBNET_ID"
    fi
done

# Import private subnet associations
echo -e "\n${YELLOW}Importing private subnet associations...${NC}"
for i in 0 1; do
    SUBNET_ID="${PRIVATE_SUBNETS[$i]}"
    RESULT=$(get_association "$SUBNET_ID")
    if [ -n "$RESULT" ]; then
        ASSOC_ID=$(echo "$RESULT" | awk '{print $1}')
        RT_ID=$(echo "$RESULT" | awk '{print $2}')
        echo "  Private[$i]: $SUBNET_ID -> RT $RT_ID (assoc: $ASSOC_ID)"
        
        if [ "$RT_ID" != "$PUBLIC_RT_ID" ]; then
            echo "    Importing route table $RT_ID..."
            terraform import "module.subnets.aws_route_table.private[$i]" "$RT_ID" 2>/dev/null || echo "    (already imported or error)"
        fi
        
        echo "    Importing association..."
        terraform import "module.subnets.aws_route_table_association.private[$i]" "$ASSOC_ID" 2>/dev/null || echo "    (already imported or error)"
    else
        echo "  No association found for private[$i]: $SUBNET_ID"
    fi
done

# Import management subnet associations
echo -e "\n${YELLOW}Importing management subnet associations...${NC}"
for i in 0 1 2; do
    SUBNET_ID="${MANAGEMENT_SUBNETS[$i]}"
    RESULT=$(get_association "$SUBNET_ID")
    if [ -n "$RESULT" ]; then
        ASSOC_ID=$(echo "$RESULT" | awk '{print $1}')
        RT_ID=$(echo "$RESULT" | awk '{print $2}')
        echo "  Management[$i]: $SUBNET_ID -> RT $RT_ID (assoc: $ASSOC_ID)"
        
        if [ "$RT_ID" != "$PUBLIC_RT_ID" ]; then
            echo "    Importing route table $RT_ID..."
            terraform import "module.subnets.aws_route_table.management[$i]" "$RT_ID" 2>/dev/null || echo "    (already imported or error)"
        fi
        
        echo "    Importing association..."
        terraform import "module.subnets.aws_route_table_association.management[$i]" "$ASSOC_ID" 2>/dev/null || echo "    (already imported or error)"
    else
        echo "  No association found for management[$i]: $SUBNET_ID"
    fi
done

# Import public subnet associations
echo -e "\n${YELLOW}Importing public subnet associations...${NC}"
for i in 0 1; do
    SUBNET_ID="${PUBLIC_SUBNETS[$i]}"
    RESULT=$(get_association "$SUBNET_ID")
    if [ -n "$RESULT" ]; then
        ASSOC_ID=$(echo "$RESULT" | awk '{print $1}')
        RT_ID=$(echo "$RESULT" | awk '{print $2}')
        echo "  Public[$i]: $SUBNET_ID -> RT $RT_ID (assoc: $ASSOC_ID)"
        
        echo "    Importing association..."
        terraform import "module.subnets.aws_route_table_association.public[$i]" "$ASSOC_ID" 2>/dev/null || echo "    (already imported or error)"
    else
        echo "  No association found for public[$i]: $SUBNET_ID"
    fi
done

# ==============================================================================
# IMPORT PUBLIC ROUTE (0.0.0.0/0 -> IGW)
# ==============================================================================
echo -e "\n${GREEN}Importing public internet route...${NC}"
IGW_ID="igw-080148380977d9e5d"
# Route import format: route_table_id_destination
terraform import "module.subnets.aws_route.public_internet[0]" "${PUBLIC_RT_ID}_0.0.0.0/0" 2>/dev/null || echo "(already imported or error)"

# ==============================================================================
# IMPORT INSPECTION ROUTES TO NAT
# ==============================================================================
echo -e "\n${GREEN}Looking for inspection routes to NAT...${NC}"

# Get inspection route tables and check for NAT routes
for i in 0 1; do
    SUBNET_ID="${INSPECTION_SUBNETS[$i]}"
    RT_INFO=$(aws ec2 describe-route-tables --region $REGION \
        --query "RouteTables[?Associations[?SubnetId=='$SUBNET_ID']].[RouteTableId,Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId]" \
        --output text)
    
    RT_ID=$(echo "$RT_INFO" | head -1)
    NAT_ID=$(echo "$RT_INFO" | tail -1 | tr -d '[:space:]')
    
    if [ -n "$NAT_ID" ] && [ "$NAT_ID" != "None" ]; then
        echo "  Inspection[$i] RT $RT_ID has NAT route to $NAT_ID"
        terraform import "module.subnets.aws_route.inspection_to_nat[$i]" "${RT_ID}_0.0.0.0/0" 2>/dev/null || echo "    (already imported or error)"
    fi
done

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Route import complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nRun 'terraform plan' to check the state."
