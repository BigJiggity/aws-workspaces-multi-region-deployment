#!/bin/bash
# ==============================================================================
# ARCHIVE OLD PROJECTS SCRIPT
# Moves old networking project directories to an archive location
#
# Projects to Archive:
#   - org-vpc_firewall_us-east-2-account-111122223333
#   - org-vpc-tgw-firewall-useast-1
#   - landing_zones/account-111122223333/ap-southeast-1_manilla_localzone
#
# IMPORTANT: Run migrate-state.sh FIRST and verify new deployments work!
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
ARCHIVE_DIR="${CLOUD_INFRA_DIR}/_archived/networking-consolidation-$(date +%Y%m%d)"

echo "=============================================="
echo "Generic AWS Networking - Archive Old Projects"
echo "=============================================="
echo ""
echo -e "${CYAN}Cloud Infrastructure Directory: ${CLOUD_INFRA_DIR}${NC}"
echo -e "${CYAN}Archive Directory: ${ARCHIVE_DIR}${NC}"
echo ""

# Projects to archive
declare -A PROJECTS=(
    ["org-vpc_firewall_us-east-2-account-111122223333"]="us-east-2 VPC/Firewall (old)"
    ["org-vpc-tgw-firewall-useast-1"]="us-east-1 VPC/Firewall (old)"
)

# Also handle landing zones subdirectory
MANILA_OLD="${CLOUD_INFRA_DIR}/landing_zones/account-111122223333/ap-southeast-1_manilla_localzone"

echo "The following directories will be archived:"
echo ""

for project in "${!PROJECTS[@]}"; do
    PROJECT_DIR="${CLOUD_INFRA_DIR}/${project}"
    if [ -d "$PROJECT_DIR" ]; then
        SIZE=$(du -sh "$PROJECT_DIR" 2>/dev/null | cut -f1)
        echo -e "  ${YELLOW}✓${NC} ${project} (${SIZE})"
        echo -e "    ${PROJECTS[$project]}"
    else
        echo -e "  ${RED}✗${NC} ${project} (not found)"
    fi
done

if [ -d "$MANILA_OLD" ]; then
    SIZE=$(du -sh "$MANILA_OLD" 2>/dev/null | cut -f1)
    echo -e "  ${YELLOW}✓${NC} landing_zones/.../ap-southeast-1_manilla_localzone (${SIZE})"
    echo -e "    ap-southeast-1 Manila Landing Zone (old)"
else
    echo -e "  ${RED}✗${NC} Manila landing zone (not found)"
fi

echo ""
echo -e "${RED}WARNING: This will MOVE these directories to the archive.${NC}"
echo -e "${RED}Make sure you have:${NC}"
echo -e "${RED}  1. Run migrate-state.sh successfully${NC}"
echo -e "${RED}  2. Verified terraform plan works in new locations${NC}"
echo -e "${RED}  3. Tested infrastructure connectivity${NC}"
echo ""
read -p "Do you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Archive cancelled."
    exit 0
fi

echo ""

# Create archive directory
mkdir -p "$ARCHIVE_DIR"

# Archive each project
for project in "${!PROJECTS[@]}"; do
    PROJECT_DIR="${CLOUD_INFRA_DIR}/${project}"
    
    if [ -d "$PROJECT_DIR" ]; then
        echo -e "${CYAN}Archiving ${project}...${NC}"
        
        # Remove .terraform directory (providers, can be re-downloaded)
        if [ -d "${PROJECT_DIR}/.terraform" ]; then
            echo "  Removing .terraform directory..."
            rm -rf "${PROJECT_DIR}/.terraform"
        fi
        
        # Move to archive
        mv "$PROJECT_DIR" "${ARCHIVE_DIR}/"
        echo -e "  ${GREEN}✓ Moved to ${ARCHIVE_DIR}/${project}${NC}"
    else
        echo -e "${YELLOW}Skipping ${project} (not found)${NC}"
    fi
done

# Archive Manila landing zone
if [ -d "$MANILA_OLD" ]; then
    echo -e "${CYAN}Archiving Manila landing zone...${NC}"
    
    # Remove .terraform directory
    if [ -d "${MANILA_OLD}/.terraform" ]; then
        echo "  Removing .terraform directory..."
        rm -rf "${MANILA_OLD}/.terraform"
    fi
    
    # Move to archive
    mv "$MANILA_OLD" "${ARCHIVE_DIR}/ap-southeast-1_manilla_localzone"
    echo -e "  ${GREEN}✓ Moved to ${ARCHIVE_DIR}/ap-southeast-1_manilla_localzone${NC}"
else
    echo -e "${YELLOW}Skipping Manila landing zone (not found)${NC}"
fi

echo ""

# Create a README in archive directory
cat > "${ARCHIVE_DIR}/README.md" << 'EOF'
# Archived Networking Projects

These projects were archived on $(date +%Y-%m-%d) as part of the networking consolidation.

## New Location

All networking infrastructure is now managed from:
```
org-aws-networking/account-111122223333/
├── us-east-1/      # 10.4.0.0/16 - WorkSpaces VDI
├── us-east-2/      # 10.0.0.0/16 - Primary DCs
└── ap-southeast-1/ # 10.2.0.0/16 - Manila WorkSpaces, DC03
```

## Archived Projects

| Old Project | New Location |
|-------------|--------------|
| org-vpc_firewall_us-east-2-account-111122223333 | us-east-2/ |
| org-vpc-tgw-firewall-useast-1 | us-east-1/ |
| ap-southeast-1_manilla_localzone | ap-southeast-1/ |

## State Migration

Terraform state was migrated to new S3 keys:
- `networking/us-east-2/terraform.tfstate`
- `networking/us-east-1/terraform.tfstate`
- `networking/ap-southeast-1/terraform.tfstate`

## Recovery

If you need to recover any of these projects:
1. Move the directory back to `cloud_infrastructure/`
2. Update backend.tf to point to the old state key
3. Run `terraform init`

EOF

# Update the README with actual date
sed -i.bak "s/\$(date +%Y-%m-%d)/$(date +%Y-%m-%d)/g" "${ARCHIVE_DIR}/README.md"
rm -f "${ARCHIVE_DIR}/README.md.bak"

echo "=============================================="
echo -e "${GREEN}Archive complete!${NC}"
echo ""
echo "Archived projects location: ${ARCHIVE_DIR}"
echo ""
echo "Directory structure:"
ls -la "$ARCHIVE_DIR"
echo ""
echo -e "${YELLOW}Remember: Old Terraform state is still in S3.${NC}"
echo -e "${YELLOW}You can delete it after verifying everything works.${NC}"
echo ""
echo "To delete old state (when ready):"
echo "  aws s3 rm s3://org-terraform-state-account-111122223333-111122223333/us-east-2/account-111122223333/ --recursive"
echo "  aws s3 rm s3://org-terraform-state-account-111122223333-111122223333-ap-southeast-1/backend-setup/ --recursive"
