#!/bin/bash
# ==============================================================================
# US-EAST-2 STATE FIX SCRIPT
# Fixes the import order for subnets that were imported in wrong order
# ==============================================================================

set -e

cd "$(dirname "$0")/../../us-east-2"

echo "Fixing state for us-east-2..."

# ==============================================================================
# FIX TGW ATTACHMENT SUBNETS
# Current: [0]=10.0.200.16/28, [1]=10.0.200.0/28
# Need:    [0]=10.0.200.0/28,  [1]=10.0.200.16/28
# ==============================================================================
echo "Fixing TGW attachment subnet order..."
terraform state mv 'module.subnets.aws_subnet.tgw_attachment[0]' 'module.subnets.aws_subnet.tgw_attachment_temp'
terraform state mv 'module.subnets.aws_subnet.tgw_attachment[1]' 'module.subnets.aws_subnet.tgw_attachment[0]'
terraform state mv 'module.subnets.aws_subnet.tgw_attachment_temp' 'module.subnets.aws_subnet.tgw_attachment[1]'

# ==============================================================================
# FIX MANAGEMENT SUBNETS
# Current: [0]=10.0.14.0/24(2c), [1]=10.0.12.0/24(2a), [2]=10.0.13.0/24(2b)
# Need:    [0]=10.0.12.0/24(2a), [1]=10.0.13.0/24(2b), [2]=10.0.14.0/24(2a)
#
# Rotation needed:
#   [0] → [2]
#   [1] → [0]
#   [2] → [1]
# ==============================================================================
echo "Fixing management subnet order..."
# First move [0] to temp
terraform state mv 'module.subnets.aws_subnet.management[0]' 'module.subnets.aws_subnet.management_temp0'
# Move [1] to [0]
terraform state mv 'module.subnets.aws_subnet.management[1]' 'module.subnets.aws_subnet.management[0]'
# Move [2] to [1]
terraform state mv 'module.subnets.aws_subnet.management[2]' 'module.subnets.aws_subnet.management[1]'
# Move temp to [2]
terraform state mv 'module.subnets.aws_subnet.management_temp0' 'module.subnets.aws_subnet.management[2]'

echo "State fix complete!"
echo ""
echo "Now run: terraform plan"
