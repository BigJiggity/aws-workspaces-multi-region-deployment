#!/bin/bash
# ==============================================================================
# TERRAFORM VALIDATION SCRIPT
# Validates all region deployments in org-aws-networking
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=============================================="
echo "Generic AWS Networking - Terraform Validation"
echo "=============================================="
echo ""

REGIONS=("us-east-1" "us-east-2" "ap-southeast-1")
FAILED=0

for region in "${REGIONS[@]}"; do
    echo -e "${YELLOW}Validating ${region}...${NC}"
    
    REGION_DIR="${BASE_DIR}/${region}"
    
    if [ ! -d "$REGION_DIR" ]; then
        echo -e "${RED}  ✗ Directory not found: ${REGION_DIR}${NC}"
        FAILED=1
        continue
    fi
    
    cd "$REGION_DIR"
    
    # Initialize without backend (local validation only)
    echo "  Initializing terraform (backend=false)..."
    if terraform init -backend=false -input=false > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Init successful${NC}"
    else
        echo -e "  ${RED}✗ Init failed${NC}"
        terraform init -backend=false -input=false
        FAILED=1
        continue
    fi
    
    # Validate configuration
    echo "  Validating configuration..."
    if terraform validate > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Validation successful${NC}"
    else
        echo -e "  ${RED}✗ Validation failed${NC}"
        terraform validate
        FAILED=1
        continue
    fi
    
    # Format check
    echo "  Checking formatting..."
    if terraform fmt -check -recursive > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Formatting OK${NC}"
    else
        echo -e "  ${YELLOW}⚠ Formatting issues (run: terraform fmt -recursive)${NC}"
    fi
    
    echo ""
done

# Validate shared modules
echo -e "${YELLOW}Validating shared modules...${NC}"
MODULES_DIR="${BASE_DIR}/modules"

for module in vpc subnets network-firewall transit-gateway tgw-peering; do
    MODULE_DIR="${MODULES_DIR}/${module}"
    if [ -f "${MODULE_DIR}/main.tf" ]; then
        echo -e "  ${GREEN}✓ ${module}/main.tf exists${NC}"
    else
        echo -e "  ${RED}✗ ${module}/main.tf missing${NC}"
        FAILED=1
    fi
done

echo ""
echo "=============================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All validations passed!${NC}"
    exit 0
else
    echo -e "${RED}Some validations failed${NC}"
    exit 1
fi
