#!/bin/bash
# ==============================================================================
# STATE MIGRATION SCRIPT
# Migrates Terraform state from old project locations to new consolidated structure
#
# Old Locations & State:
#   - org-vpc_firewall_us-east-2-account-111122223333
#     Bucket: org-terraform-state-account-111122223333-111122223333
#     Key: us-east-2/account-111122223333/terraform.tfstate
#     DynamoDB: org-terraform-state-account-111122223333
#
#   - landing_zones/account-111122223333/ap-southeast-1_manilla_localzone
#     Bucket: org-terraform-state-account-111122223333-111122223333-ap-southeast-1
#     Key: backend-setup/terraform.tfstate
#     DynamoDB: org-terraform-state-account-111122223333-ap-southeast-1
#
#   - org-vpc-tgw-firewall-useast-1 (NEW - no existing state)
#
# New State Locations (all in same bucket):
#   - Bucket: org-terraform-state-account-111122223333-111122223333
#   - Keys:
#     - networking/us-east-2/terraform.tfstate
#     - networking/us-east-1/terraform.tfstate
#     - networking/ap-southeast-1/terraform.tfstate
#   - DynamoDB: terraform-state-lock
#
# IMPORTANT: Run this script BEFORE deploying from the new locations!
# ==============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CLOUD_INFRA_DIR="$(dirname "$(dirname "$(dirname "$BASE_DIR")")")"
BACKUP_DIR="${BASE_DIR}/state-backups/$(date +%Y%m%d_%H%M%S)"

# New consolidated bucket
NEW_S3_BUCKET="org-terraform-state-account-111122223333-111122223333"
NEW_DYNAMODB_TABLE="terraform-state-lock"

echo "=============================================="
echo "Generic AWS Networking - State Migration"
echo "=============================================="
echo ""
echo -e "${CYAN}Cloud Infrastructure Directory: ${CLOUD_INFRA_DIR}${NC}"
echo -e "${CYAN}Backup Directory: ${BACKUP_DIR}${NC}"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to migrate us-east-2 state
migrate_use2() {
    local OLD_BUCKET="org-terraform-state-account-111122223333-111122223333"
    local OLD_KEY="us-east-2/account-111122223333/terraform.tfstate"
    local NEW_KEY="networking/us-east-2/terraform.tfstate"
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Migrating: US-EAST-2${NC}"
    echo -e "  Old: s3://${OLD_BUCKET}/${OLD_KEY}"
    echo -e "  New: s3://${NEW_S3_BUCKET}/${NEW_KEY}"
    echo ""
    
    # Backup
    echo -e "  ${CYAN}Step 1: Backing up current state...${NC}"
    if aws s3 cp "s3://${OLD_BUCKET}/${OLD_KEY}" "${BACKUP_DIR}/us-east-2-old.tfstate" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Backed up to ${BACKUP_DIR}/us-east-2-old.tfstate${NC}"
    else
        echo -e "  ${YELLOW}⚠ No existing state found${NC}"
        return 0
    fi
    
    # Check new location
    echo -e "  ${CYAN}Step 2: Checking new state location...${NC}"
    if aws s3 ls "s3://${NEW_S3_BUCKET}/${NEW_KEY}" 2>/dev/null; then
        echo -e "  ${RED}✗ State already exists at new location!${NC}"
        echo -e "  ${RED}  Skip or manually resolve.${NC}"
        return 1
    fi
    echo -e "  ${GREEN}✓ New location is empty${NC}"
    
    # Copy
    echo -e "  ${CYAN}Step 3: Copying state to new location...${NC}"
    if aws s3 cp "${BACKUP_DIR}/us-east-2-old.tfstate" "s3://${NEW_S3_BUCKET}/${NEW_KEY}"; then
        echo -e "  ${GREEN}✓ State copied successfully${NC}"
    else
        echo -e "  ${RED}✗ Failed to copy state${NC}"
        return 1
    fi
    
    echo ""
}

# Function to migrate ap-southeast-1 state
migrate_apse1() {
    local OLD_BUCKET="org-terraform-state-account-111122223333-111122223333-ap-southeast-1"
    local OLD_KEY="backend-setup/terraform.tfstate"
    local NEW_KEY="networking/ap-southeast-1/terraform.tfstate"
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Migrating: AP-SOUTHEAST-1${NC}"
    echo -e "  Old: s3://${OLD_BUCKET}/${OLD_KEY}"
    echo -e "  New: s3://${NEW_S3_BUCKET}/${NEW_KEY}"
    echo ""
    
    # Backup
    echo -e "  ${CYAN}Step 1: Backing up current state...${NC}"
    if aws s3 cp "s3://${OLD_BUCKET}/${OLD_KEY}" "${BACKUP_DIR}/ap-southeast-1-old.tfstate" --region ap-southeast-1 2>/dev/null; then
        echo -e "  ${GREEN}✓ Backed up to ${BACKUP_DIR}/ap-southeast-1-old.tfstate${NC}"
    else
        echo -e "  ${YELLOW}⚠ No existing state found${NC}"
        return 0
    fi
    
    # Check new location
    echo -e "  ${CYAN}Step 2: Checking new state location...${NC}"
    if aws s3 ls "s3://${NEW_S3_BUCKET}/${NEW_KEY}" 2>/dev/null; then
        echo -e "  ${RED}✗ State already exists at new location!${NC}"
        echo -e "  ${RED}  Skip or manually resolve.${NC}"
        return 1
    fi
    echo -e "  ${GREEN}✓ New location is empty${NC}"
    
    # Copy
    echo -e "  ${CYAN}Step 3: Copying state to new location...${NC}"
    if aws s3 cp "${BACKUP_DIR}/ap-southeast-1-old.tfstate" "s3://${NEW_S3_BUCKET}/${NEW_KEY}"; then
        echo -e "  ${GREEN}✓ State copied successfully${NC}"
    else
        echo -e "  ${RED}✗ Failed to copy state${NC}"
        return 1
    fi
    
    echo ""
}

# Function for us-east-1 (new deployment)
check_use1() {
    local NEW_KEY="networking/us-east-1/terraform.tfstate"
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}US-EAST-1 (New Deployment)${NC}"
    echo -e "  New: s3://${NEW_S3_BUCKET}/${NEW_KEY}"
    echo ""
    
    echo -e "  ${CYAN}Checking if state exists...${NC}"
    if aws s3 ls "s3://${NEW_S3_BUCKET}/${NEW_KEY}" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠ State already exists (from previous attempt?)${NC}"
    else
        echo -e "  ${GREEN}✓ No existing state - fresh deployment${NC}"
    fi
    
    echo ""
}

# Show current state locations
echo -e "${CYAN}Current State Locations:${NC}"
echo ""
echo "US-EAST-2:"
if aws s3 ls "s3://org-terraform-state-account-111122223333-111122223333/us-east-2/account-111122223333/terraform.tfstate" 2>/dev/null; then
    echo -e "  ${GREEN}✓ State exists${NC}"
else
    echo -e "  ${YELLOW}⚠ No state found${NC}"
fi

echo ""
echo "AP-SOUTHEAST-1:"
if aws s3 ls "s3://org-terraform-state-account-111122223333-111122223333-ap-southeast-1/backend-setup/terraform.tfstate" --region ap-southeast-1 2>/dev/null; then
    echo -e "  ${GREEN}✓ State exists${NC}"
else
    echo -e "  ${YELLOW}⚠ No state found${NC}"
fi

echo ""
echo -e "${RED}WARNING: This script will migrate Terraform state files.${NC}"
echo -e "${RED}Make sure you have reviewed the migration plan.${NC}"
echo ""
read -p "Do you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""

# Run migrations
migrate_use2
migrate_apse1
check_use1

echo ""
echo "=============================================="
echo -e "${GREEN}State migration complete!${NC}"
echo ""
echo "Backups saved to: ${BACKUP_DIR}"
echo ""
echo "Next steps:"
echo "  1. cd ${BASE_DIR}"
echo "  2. ./scripts/init-all.sh"
echo "  3. cd us-east-2 && terraform plan"
echo "  4. cd ../ap-southeast-1 && terraform plan"
echo "  5. cd ../us-east-1 && terraform plan"
echo ""
echo -e "${YELLOW}IMPORTANT: Verify plans show no changes before proceeding!${NC}"
echo ""
echo "Old state locations (DO NOT DELETE until verified):"
echo "  s3://org-terraform-state-account-111122223333-111122223333/us-east-2/account-111122223333/"
echo "  s3://org-terraform-state-account-111122223333-111122223333-ap-southeast-1/backend-setup/"
