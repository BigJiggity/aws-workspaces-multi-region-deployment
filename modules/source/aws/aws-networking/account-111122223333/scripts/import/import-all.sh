#!/bin/bash
# ==============================================================================
# MASTER IMPORT SCRIPT
# Imports existing infrastructure into Terraform state for all regions
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Generic AWS NETWORKING - INFRASTRUCTURE IMPORT${NC}"
echo -e "${GREEN}============================================${NC}"

echo -e "\n${YELLOW}This script will import existing AWS infrastructure into Terraform.${NC}"
echo -e "${YELLOW}Make sure the Terraform destroys have completed first!${NC}\n"

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Make scripts executable
chmod +x "$SCRIPT_DIR/import-us-east-2.sh"
chmod +x "$SCRIPT_DIR/import-ap-southeast-1.sh"

# Run US-EAST-2 import
echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}  IMPORTING US-EAST-2${NC}"
echo -e "${GREEN}============================================${NC}"
"$SCRIPT_DIR/import-us-east-2.sh"

# Run AP-SOUTHEAST-1 import
echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}  IMPORTING AP-SOUTHEAST-1${NC}"
echo -e "${GREEN}============================================${NC}"
"$SCRIPT_DIR/import-ap-southeast-1.sh"

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}  ALL IMPORTS COMPLETE${NC}"
echo -e "${GREEN}============================================${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. cd to each region directory and run 'terraform plan'"
echo -e "  2. Review the plan output for any required changes"
echo -e "  3. Update terraform configs to match existing infrastructure"
echo -e "  4. Run 'terraform apply' to reconcile state"
echo -e "\n${YELLOW}Note: us-east-1 does not need import (new infrastructure)${NC}"
