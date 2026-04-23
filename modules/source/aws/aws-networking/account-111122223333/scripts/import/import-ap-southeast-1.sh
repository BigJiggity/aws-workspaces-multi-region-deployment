#!/bin/bash
# ==============================================================================
# AP-SOUTHEAST-1 IMPORT SCRIPT
# Imports existing infrastructure into Terraform state
#
# CRITICAL: DC03 is at 10.2.10.10 in subnet-0c4f37c9480a10f44 (management-1a)
# This script orders imports to prevent subnet replacement
#
# NOTE: Firewall rule groups and policy will be RECREATED with new names
# because existing names don't match module naming convention.
# Firewall itself will be updated in-place to use new policy.
# ==============================================================================

set -e

cd "$(dirname "$0")/../../ap-southeast-1"

echo "=============================================="
echo "AP-SOUTHEAST-1 IMPORT SCRIPT"
echo "=============================================="

# ------------------------------------------------------------------------------
# STEP 1: Remove resources from state that will be reimported
# ------------------------------------------------------------------------------
echo ""
echo "Step 1: Cleaning state for reimport..."

# Remove subnets that are in wrong order or need reimport
terraform state rm 'module.subnets.aws_subnet.management[0]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.management[1]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.management[2]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.private[0]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.private[1]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.private[2]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.tgw_attachment[0]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.tgw_attachment[1]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.tgw_attachment[2]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.vdi[0]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.vdi[1]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.vdi[2]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.inspection[0]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.inspection[1]' 2>/dev/null || true
terraform state rm 'module.subnets.aws_subnet.inspection[2]' 2>/dev/null || true

# Remove firewall policy - will be recreated with new name
terraform state rm 'module.network_firewall.aws_networkfirewall_firewall_policy.this' 2>/dev/null || true

echo "State cleaned."

# ------------------------------------------------------------------------------
# STEP 2: Import Subnets in correct CIDR order
# Order must match terraform.tfvars CIDR arrays (1a, 1b, 1c)
# ------------------------------------------------------------------------------
echo ""
echo "Step 2: Importing subnets..."

# Public/Egress subnets (10.2.101.0/28, .16/28, .32/28 -> 1a, 1b, 1c)
echo "  Importing public subnets..."
terraform import 'module.subnets.aws_subnet.public[0]' subnet-03ae9077b1ac611cc  # egress-1a 10.2.101.0/28
terraform import 'module.subnets.aws_subnet.public[1]' subnet-04ad13838c02dfb4f  # egress-1b 10.2.101.16/28
terraform import 'module.subnets.aws_subnet.public[2]' subnet-082e6ff7d3cf0d88f  # egress-1c 10.2.101.32/28

# Private/Sandbox subnets (10.2.40.0/25, .128/25, 10.2.41.0/25 -> 1a, 1b, 1c)
echo "  Importing private subnets..."
terraform import 'module.subnets.aws_subnet.private[0]' subnet-0cb64be7b3b6dcf34  # sandbox-1a 10.2.40.0/25
terraform import 'module.subnets.aws_subnet.private[1]' subnet-053bfca2aef0bbad3  # sandbox-1b 10.2.40.128/25
terraform import 'module.subnets.aws_subnet.private[2]' subnet-00dbd7e45f0ccdf31  # sandbox-1c 10.2.41.0/25

# Management subnets (10.2.10.0/25, .128/25, 10.2.11.0/25 -> 1a, 1b, 1c)
# CRITICAL: DC03 is in subnet-0c4f37c9480a10f44 (10.2.10.0/25, management-1a)
echo "  Importing management subnets (DC03 protection)..."
terraform import 'module.subnets.aws_subnet.management[0]' subnet-0c4f37c9480a10f44  # management-1a 10.2.10.0/25 (DC03!)
terraform import 'module.subnets.aws_subnet.management[1]' subnet-08fdebee816002ab1  # management-1b 10.2.10.128/25
terraform import 'module.subnets.aws_subnet.management[2]' subnet-0d2efba33378a4258  # management-1c 10.2.11.0/25

# Inspection subnets (10.2.100.0/28, .16/28, .32/28 -> 1a, 1b, 1c)
echo "  Importing inspection subnets..."
terraform import 'module.subnets.aws_subnet.inspection[0]' subnet-0660282b28f118095  # inspection-1a 10.2.100.0/28
terraform import 'module.subnets.aws_subnet.inspection[1]' subnet-08af42678ca89b8f6  # inspection-1b 10.2.100.16/28
terraform import 'module.subnets.aws_subnet.inspection[2]' subnet-0feb95a5091305b76  # inspection-1c 10.2.100.32/28

# TGW attachment subnets (10.2.110.0/28, .16/28, .32/28 -> 1a, 1b, 1c)
echo "  Importing TGW attachment subnets..."
terraform import 'module.subnets.aws_subnet.tgw_attachment[0]' subnet-033d511f98ca2da0f  # tgw-attachment-1a 10.2.110.0/28
terraform import 'module.subnets.aws_subnet.tgw_attachment[1]' subnet-0bb0223d8b0fce30f  # tgw-attachment-1b 10.2.110.16/28
terraform import 'module.subnets.aws_subnet.tgw_attachment[2]' subnet-04fea3c1164483da3  # tgw-attachment-1c 10.2.110.32/28

# VDI subnets (10.2.20.0/25, .128/25, 10.2.21.0/25 -> 1a, 1b, 1c)
echo "  Importing VDI subnets..."
terraform import 'module.subnets.aws_subnet.vdi[0]' subnet-03b225ffd3428d265  # vdi-1-1a 10.2.20.0/25
terraform import 'module.subnets.aws_subnet.vdi[1]' subnet-0863da47d4dd58bb1  # vdi-1-1b 10.2.20.128/25
terraform import 'module.subnets.aws_subnet.vdi[2]' subnet-03ce2a0ba3e9e25ea  # vdi-1-1c 10.2.21.0/25

echo "Subnets imported."

# ------------------------------------------------------------------------------
# STEP 3: Import Route Tables
# Existing uses shared RTs; Terraform creates per-AZ RTs
# Import existing shared RT to index [0], let Terraform create [1], [2]
# ------------------------------------------------------------------------------
echo ""
echo "Step 3: Importing route tables..."

# Public RT (egress-rt) -> module uses single shared public RT
echo "  Importing public route table..."
terraform import 'module.subnets.aws_route_table.public[0]' rtb-0675c2199d15126ac  # egress-rt

# Inspection RT - import shared to [0], TF creates [1], [2]
echo "  Importing inspection route table [0]..."
terraform import 'module.subnets.aws_route_table.inspection[0]' rtb-0ce8c1a311b549f00  # inspection-rt

# TGW attachment RT - import shared to [0], TF creates [1], [2]
echo "  Importing TGW route table [0]..."
terraform import 'module.subnets.aws_route_table.tgw_attachment[0]' rtb-021ab4af153465f31  # tgw-attachment-rt

# Private RT - import shared to [0], TF creates [1], [2]
echo "  Importing private route table [0]..."
terraform import 'module.subnets.aws_route_table.private[0]' rtb-064c505ac69c4ae63  # private-rt

# Management RT - no existing dedicated RT, TF will create all 3
echo "  Management route tables will be created new (currently use public-rt)..."

# VDI RT - no existing dedicated RT, TF will create all 3
echo "  VDI route tables will be created new (currently use public-rt)..."

echo "Route tables imported."

# ------------------------------------------------------------------------------
# STEP 4: Import NAT Gateway and EIP
# NAT is currently in egress-1b, but single_nat_gateway uses public[0] (egress-1a)
# This will cause NAT replacement - brief connectivity blip
# ------------------------------------------------------------------------------
echo ""
echo "Step 4: Importing NAT Gateway..."
echo "  NOTE: NAT Gateway will be replaced (moving from 1b to 1a subnet)"

terraform import 'module.subnets.aws_eip.nat[0]' eipalloc-05e26238b4e496991
terraform import 'module.subnets.aws_nat_gateway.this[0]' nat-019808b503b75a6cc

echo "NAT Gateway imported (will be replaced on apply)."

# ------------------------------------------------------------------------------
# STEP 5: Import CloudWatch Log Groups (if they exist)
# Firewall rule groups and policy will be recreated with new names
# ------------------------------------------------------------------------------
echo ""
echo "Step 5: Importing CloudWatch log groups..."

terraform import 'module.network_firewall.aws_cloudwatch_log_group.alerts[0]' \
  '/aws/networkfirewall/manila-landing-pad-firewall/alerts' 2>/dev/null || echo "  Alerts log group will be created"

terraform import 'module.network_firewall.aws_cloudwatch_log_group.flow[0]' \
  '/aws/networkfirewall/manila-landing-pad-firewall/flow' 2>/dev/null || echo "  Flow log group will be created"

echo "Log groups handled."

# ------------------------------------------------------------------------------
# STEP 6: Import Firewall Logging Configuration
# ------------------------------------------------------------------------------
echo ""
echo "Step 6: Importing firewall logging configuration..."

terraform import 'module.network_firewall.aws_networkfirewall_logging_configuration.this' \
  'arn:aws:network-firewall:ap-southeast-1:111122223333:firewall/manila-landing-pad-firewall' 2>/dev/null || echo "  Logging config will be created"

echo "Logging configuration handled."

# ------------------------------------------------------------------------------
# STEP 7: Import TGW Routes (if they exist)
# ------------------------------------------------------------------------------
echo ""
echo "Step 7: Importing TGW routes..."

terraform import 'aws_ec2_transit_gateway_route.to_use2[0]' \
  'tgw-rtb-04e5cf4513071c7a6_5.10.2.0/16' 2>/dev/null || echo "  Route to USE2 will be created"

terraform import 'aws_ec2_transit_gateway_route.to_use1[0]' \
  'tgw-rtb-04e5cf4513071c7a6_10.4.0.0/16' 2>/dev/null || echo "  Route to USE1 will be created"

echo "TGW routes handled."

# ------------------------------------------------------------------------------
# STEP 8: Import Public Route Table Routes
# ------------------------------------------------------------------------------
echo ""
echo "Step 8: Importing route table routes..."

# Public RT internet route
terraform import 'module.subnets.aws_route.public_internet[0]' \
  'rtb-0675c2199d15126ac_0.0.0.0/0' 2>/dev/null || echo "  Public internet route will be created"

# Inspection RT NAT route (only for [0] since shared RT)
terraform import 'module.subnets.aws_route.inspection_to_nat[0]' \
  'rtb-0ce8c1a311b549f00_0.0.0.0/0' 2>/dev/null || echo "  Inspection NAT route will be created"

echo "Routes handled."

# ------------------------------------------------------------------------------
# COMPLETE
# ------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "IMPORT COMPLETE"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Run: terraform plan"
echo ""
echo "2. Review changes - EXPECTED:"
echo "   - NEW route tables: inspection[1,2], tgw[1,2], private[1,2], management[0,1,2], vdi[0,1,2]"
echo "   - NEW firewall rule groups (different names than existing)"
echo "   - NEW firewall policy (different name than existing)"
echo "   - NAT Gateway REPLACEMENT (moving to different subnet)"
echo "   - Route table associations (subnets moving to new RTs)"
echo "   - Tag updates on existing resources"
echo ""
echo "3. CRITICAL CHECK before apply:"
echo "   - Verify management subnet[0] is NOT being replaced!"
echo "   - DC03 (10.2.10.10) must remain in subnet-0c4f37c9480a10f44"
echo "   - If management[0] shows 'must be replaced' - STOP and investigate!"
echo ""
echo "4. If plan looks safe, run: terraform apply"
echo ""
echo "WARNING: This will cause brief connectivity disruption during:"
echo "   - NAT Gateway replacement (~2-3 minutes)"
echo "   - Firewall policy switch (brief)"
