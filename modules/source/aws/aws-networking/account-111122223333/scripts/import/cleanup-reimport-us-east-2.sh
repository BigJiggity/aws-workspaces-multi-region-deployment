#!/bin/bash
# ==============================================================================
# US-EAST-2 ROUTE TABLE CLEANUP AND REIMPORT
# Removes Terraform-created route tables and imports original ones
# ==============================================================================

set -e

REGION="us-east-2"
TF_DIR="$(dirname "$0")/../../us-east-2"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}US-EAST-2 Route Table Cleanup & Reimport${NC}"
echo -e "${GREEN}========================================${NC}"

cd "$TF_DIR"
echo -e "${YELLOW}Working directory: $(pwd)${NC}"

# ==============================================================================
# STEP 1: GET CURRENT STATE RT IDs (the new ones Terraform created)
# ==============================================================================
echo -e "\n${GREEN}Step 1: Getting route table IDs from Terraform state...${NC}"

# These are the NEW route tables Terraform created (empty, no associations)
NEW_INSPECTION_RT_0=$(terraform state show 'module.subnets.aws_route_table.inspection[0]' 2>/dev/null | grep "^    id " | awk '{print $3}' | tr -d '"')
NEW_INSPECTION_RT_1=$(terraform state show 'module.subnets.aws_route_table.inspection[1]' 2>/dev/null | grep "^    id " | awk '{print $3}' | tr -d '"')
NEW_MANAGEMENT_RT_0=$(terraform state show 'module.subnets.aws_route_table.management[0]' 2>/dev/null | grep "^    id " | awk '{print $3}' | tr -d '"')
NEW_MANAGEMENT_RT_1=$(terraform state show 'module.subnets.aws_route_table.management[1]' 2>/dev/null | grep "^    id " | awk '{print $3}' | tr -d '"')
NEW_MANAGEMENT_RT_2=$(terraform state show 'module.subnets.aws_route_table.management[2]' 2>/dev/null | grep "^    id " | awk '{print $3}' | tr -d '"')
NEW_PRIVATE_RT_0=$(terraform state show 'module.subnets.aws_route_table.private[0]' 2>/dev/null | grep "^    id " | awk '{print $3}' | tr -d '"')
NEW_PRIVATE_RT_1=$(terraform state show 'module.subnets.aws_route_table.private[1]' 2>/dev/null | grep "^    id " | awk '{print $3}' | tr -d '"')
NEW_TGW_RT_0=$(terraform state show 'module.subnets.aws_route_table.tgw_attachment[0]' 2>/dev/null | grep "^    id " | awk '{print $3}' | tr -d '"')
NEW_TGW_RT_1=$(terraform state show 'module.subnets.aws_route_table.tgw_attachment[1]' 2>/dev/null | grep "^    id " | awk '{print $3}' | tr -d '"')

echo "New route tables in state:"
echo "  inspection[0]: $NEW_INSPECTION_RT_0"
echo "  inspection[1]: $NEW_INSPECTION_RT_1"
echo "  management[0]: $NEW_MANAGEMENT_RT_0"
echo "  management[1]: $NEW_MANAGEMENT_RT_1"
echo "  management[2]: $NEW_MANAGEMENT_RT_2"
echo "  private[0]: $NEW_PRIVATE_RT_0"
echo "  private[1]: $NEW_PRIVATE_RT_1"
echo "  tgw_attachment[0]: $NEW_TGW_RT_0"
echo "  tgw_attachment[1]: $NEW_TGW_RT_1"

# ==============================================================================
# STEP 2: REMOVE FROM TERRAFORM STATE
# ==============================================================================
echo -e "\n${GREEN}Step 2: Removing new route tables from Terraform state...${NC}"

terraform state rm 'module.subnets.aws_route_table.inspection[0]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_route_table.inspection[1]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_route_table.management[0]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_route_table.management[1]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_route_table.management[2]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_route_table.private[0]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_route_table.private[1]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_route_table.tgw_attachment[0]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_route_table.tgw_attachment[1]' 2>/dev/null || true

# Also remove public associations if they exist
terraform state rm 'module.subnets.aws_route_table_association.public[0]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_route_table_association.public[1]' 2>/dev/null || true

echo "State removal complete."

# ==============================================================================
# STEP 3: DELETE NEW ROUTE TABLES FROM AWS
# ==============================================================================
echo -e "\n${GREEN}Step 3: Deleting new (empty) route tables from AWS...${NC}"

delete_rt() {
    local rt_id=$1
    local name=$2
    if [ -n "$rt_id" ] && [ "$rt_id" != "null" ] && [ "$rt_id" != "rtb-0a67abc53eec50633" ]; then
        echo "  Deleting $name: $rt_id"
        aws ec2 delete-route-table --region $REGION --route-table-id "$rt_id" 2>/dev/null || echo "    (failed or already deleted)"
    fi
}

delete_rt "$NEW_INSPECTION_RT_0" "inspection[0]"
delete_rt "$NEW_INSPECTION_RT_1" "inspection[1]"
delete_rt "$NEW_MANAGEMENT_RT_0" "management[0]"
delete_rt "$NEW_MANAGEMENT_RT_1" "management[1]"
delete_rt "$NEW_MANAGEMENT_RT_2" "management[2]"
delete_rt "$NEW_PRIVATE_RT_0" "private[0]"
delete_rt "$NEW_PRIVATE_RT_1" "private[1]"
delete_rt "$NEW_TGW_RT_0" "tgw[0]"
delete_rt "$NEW_TGW_RT_1" "tgw[1]"

# Also delete any orphaned ones from the list
echo "  Cleaning up any other orphaned route tables..."
for rt in rtb-0ff93761646c565e5 rtb-0186301842bfb09b2; do
    aws ec2 delete-route-table --region $REGION --route-table-id "$rt" 2>/dev/null || true
done

echo "AWS cleanup complete."

# ==============================================================================
# STEP 4: IMPORT ORIGINAL ROUTE TABLES
# ==============================================================================
echo -e "\n${GREEN}Step 4: Importing original route tables...${NC}"

# Original route tables (the ones with actual subnet associations)
# Inspection
echo "Importing inspection route tables..."
terraform import 'module.subnets.aws_route_table.inspection[0]' "rtb-0086200547b98e5b8"  # org-use2-inspection-rt-2a
terraform import 'module.subnets.aws_route_table.inspection[1]' "rtb-073d609c81084230e"  # org-use2-inspection-rt-2b

# Management  
echo "Importing management route tables..."
terraform import 'module.subnets.aws_route_table.management[0]' "rtb-00baedd854fec467c"  # org-use2-management-rt-2a
terraform import 'module.subnets.aws_route_table.management[1]' "rtb-002ee8643a10c1be4"  # org-use2-management-rt-2b
terraform import 'module.subnets.aws_route_table.management[2]' "rtb-0ce0c65d789ddc295"  # org-use2-management-rt-2c

# Private
echo "Importing private route tables..."
terraform import 'module.subnets.aws_route_table.private[0]' "rtb-0b33f69d50f562fb6"  # org-use2-private-rt-2a
terraform import 'module.subnets.aws_route_table.private[1]' "rtb-0874aec10ad03b26c"  # org-use2-private-rt-2b

# TGW Attachment
echo "Importing TGW attachment route tables..."
terraform import 'module.subnets.aws_route_table.tgw_attachment[0]' "rtb-0c0f5a7587b0be72f"  # org-use2-tgw-rt-2a
terraform import 'module.subnets.aws_route_table.tgw_attachment[1]' "rtb-0209de0ad5965d765"  # org-use2-tgw-rt-2b

# ==============================================================================
# STEP 5: IMPORT ROUTE TABLE ASSOCIATIONS
# Format: subnet_id/route_table_id
# ==============================================================================
echo -e "\n${GREEN}Step 5: Importing route table associations...${NC}"

# Public (subnet -> public RT rtb-0a67abc53eec50633)
echo "Importing public associations..."
terraform import 'module.subnets.aws_route_table_association.public[0]' "subnet-07ae679ec03e61490/rtb-0a67abc53eec50633"
terraform import 'module.subnets.aws_route_table_association.public[1]' "subnet-098bdd5938edb0833/rtb-0a67abc53eec50633"

# Inspection (subnet -> inspection RTs)
echo "Importing inspection associations..."
terraform import 'module.subnets.aws_route_table_association.inspection[0]' "subnet-04bf0f879377681ad/rtb-0086200547b98e5b8"
terraform import 'module.subnets.aws_route_table_association.inspection[1]' "subnet-0c413fecab423a4ff/rtb-073d609c81084230e"

# Management (subnet -> management RTs)
echo "Importing management associations..."
terraform import 'module.subnets.aws_route_table_association.management[0]' "subnet-0a7442960deb174d8/rtb-00baedd854fec467c"
terraform import 'module.subnets.aws_route_table_association.management[1]' "subnet-0cc704fdbd559db03/rtb-002ee8643a10c1be4"
terraform import 'module.subnets.aws_route_table_association.management[2]' "subnet-0750672f34aa1d123/rtb-0ce0c65d789ddc295"

# Private (subnet -> private RTs)
echo "Importing private associations..."
terraform import 'module.subnets.aws_route_table_association.private[0]' "subnet-007b741225dc6acf8/rtb-0b33f69d50f562fb6"
terraform import 'module.subnets.aws_route_table_association.private[1]' "subnet-03aa35eff2949941e/rtb-0874aec10ad03b26c"

# TGW Attachment (subnet -> tgw RTs)
echo "Importing TGW attachment associations..."
terraform import 'module.subnets.aws_route_table_association.tgw_attachment[0]' "subnet-085543e519c1bead4/rtb-0c0f5a7587b0be72f"
terraform import 'module.subnets.aws_route_table_association.tgw_attachment[1]' "subnet-036d2a3af5f2a8832/rtb-0209de0ad5965d765"

# ==============================================================================
# STEP 6: IMPORT PUBLIC INTERNET ROUTE
# ==============================================================================
echo -e "\n${GREEN}Step 6: Importing public internet route...${NC}"
terraform import 'module.subnets.aws_route.public_internet[0]' "rtb-0a67abc53eec50633_0.0.0.0/0" 2>/dev/null || echo "(already imported)"

# ==============================================================================
# STEP 7: IMPORT INSPECTION NAT ROUTES (if they exist)
# ==============================================================================
echo -e "\n${GREEN}Step 7: Checking for inspection NAT routes...${NC}"

# Check if inspection route tables have NAT routes
NAT_ROUTE_0=$(aws ec2 describe-route-tables --region $REGION --route-table-ids rtb-0086200547b98e5b8 \
    --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId' --output text 2>/dev/null)
NAT_ROUTE_1=$(aws ec2 describe-route-tables --region $REGION --route-table-ids rtb-073d609c81084230e \
    --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId' --output text 2>/dev/null)

if [ -n "$NAT_ROUTE_0" ] && [ "$NAT_ROUTE_0" != "None" ]; then
    echo "  Inspection[0] has NAT route, importing..."
    terraform import 'module.subnets.aws_route.inspection_to_nat[0]' "rtb-0086200547b98e5b8_0.0.0.0/0" 2>/dev/null || true
fi

if [ -n "$NAT_ROUTE_1" ] && [ "$NAT_ROUTE_1" != "None" ]; then
    echo "  Inspection[1] has NAT route, importing..."
    terraform import 'module.subnets.aws_route.inspection_to_nat[1]' "rtb-073d609c81084230e_0.0.0.0/0" 2>/dev/null || true
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup and reimport complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nRun 'terraform plan' to verify the state."
