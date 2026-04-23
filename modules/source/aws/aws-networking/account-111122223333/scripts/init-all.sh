#!/bin/bash
# ==============================================================================
# TERRAFORM INIT ALL REGIONS
# Initializes Terraform in all region directories
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================================="
echo "Generic AWS Networking - Initialize All Regions"
echo "=============================================="
echo ""

REGIONS=("us-east-2" "ap-southeast-1" "us-east-1")

for region in "${REGIONS[@]}"; do
    echo -e "${YELLOW}Initializing ${region}...${NC}"
    
    REGION_DIR="${BASE_DIR}/${region}"
    
    if [ ! -d "$REGION_DIR" ]; then
        echo -e "${RED}  ✗ Directory not found: ${REGION_DIR}${NC}"
        continue
    fi
    
    cd "$REGION_DIR"
    
    # Remove old .terraform if exists (clean init)
    if [ -d ".terraform" ]; then
        echo "  Removing old .terraform directory..."
        rm -rf .terraform
        rm -f .terraform.lock.hcl
    fi
    
    # Initialize
    echo "  Running terraform init..."
    if terraform init -input=false; then
        echo -e "  ${GREEN}✓ Initialized successfully${NC}"
    else
        echo -e "  ${RED}✗ Initialization failed${NC}"
        exit 1
    fi
    
    echo ""
done

echo "=============================================="
echo -e "${GREEN}All regions initialized!${NC}"
echo ""
echo "Next steps:"
echo "  1. cd us-east-2 && terraform plan"
echo "  2. cd ap-southeast-1 && terraform plan"
echo "  3. cd us-east-1 && terraform plan"
