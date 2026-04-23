#!/bin/bash
# ==============================================================================
# update-inventory.sh
# Updates Ansible inventory with instance IDs from Terraform output
#
# Usage: ./update-inventory.sh
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY_FILE="$SCRIPT_DIR/inventory/hosts.yml"

echo "=========================================="
echo "Updating Ansible Inventory from Terraform"
echo "=========================================="

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Check if terraform state exists
if ! terraform state list &>/dev/null; then
    echo "ERROR: No Terraform state found. Run 'terraform apply' first."
    exit 1
fi

# Get instance IDs from terraform output
echo "Getting instance IDs from Terraform..."

DC01_ID=$(terraform output -raw dc01_instance_id 2>/dev/null || echo "")
DC02_ID=$(terraform output -raw dc02_instance_id 2>/dev/null || echo "")
DC03_ID=$(terraform output -raw dc03_instance_id 2>/dev/null || echo "")

if [ -z "$DC01_ID" ] || [ -z "$DC02_ID" ] || [ -z "$DC03_ID" ]; then
    echo "ERROR: Could not get all instance IDs from Terraform output."
    echo "  DC01: ${DC01_ID:-NOT FOUND}"
    echo "  DC02: ${DC02_ID:-NOT FOUND}"
    echo "  DC03: ${DC03_ID:-NOT FOUND}"
    exit 1
fi

echo "Found instance IDs:"
echo "  DC01: $DC01_ID"
echo "  DC02: $DC02_ID"
echo "  DC03: $DC03_ID"

# Backup existing inventory
cp "$INVENTORY_FILE" "${INVENTORY_FILE}.bak"
echo "Backed up inventory to ${INVENTORY_FILE}.bak"

# Update inventory file using sed
echo "Updating inventory file..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed requires empty string after -i
    # Update DC01 (first occurrence under dc01: block)
    sed -i '' '/dc01:/,/dc02:/{s/ansible_aws_ssm_instance_id: "i-[a-f0-9x]*"/ansible_aws_ssm_instance_id: "'"$DC01_ID"'"/;}' "$INVENTORY_FILE"
    
    # Update DC02 (under dc02: block)
    sed -i '' '/dc02:/,/dc_ap_southeast_1://{s/ansible_aws_ssm_instance_id: "i-[a-f0-9x]*"/ansible_aws_ssm_instance_id: "'"$DC02_ID"'"/;}' "$INVENTORY_FILE"
    
    # Update DC03 (under dc03: block)
    sed -i '' '/dc03:/,/primary_dc:/'{s/ansible_aws_ssm_instance_id:\ \"i-[a-f0-9x]*\"/ansible_aws_ssm_instance_id:\ \"'"$DC03_ID"'\"/';} "$INVENTORY_FILE"
else
    # Linux sed
    sed -i '/dc01:/,/dc02:/{s/ansible_aws_ssm_instance_id: "i-[a-f0-9x]*"/ansible_aws_ssm_instance_id: "'"$DC01_ID"'"/;}' "$INVENTORY_FILE"
    sed -i '/dc02:/,/dc_ap_southeast_1:/{s/ansible_aws_ssm_instance_id: "i-[a-f0-9x]*"/ansible_aws_ssm_instance_id: "'"$DC02_ID"'"/;}' "$INVENTORY_FILE"
    sed -i '/dc03:/,/primary_dc:/{s/ansible_aws_ssm_instance_id: "i-[a-f0-9x]*"/ansible_aws_ssm_instance_id: "'"$DC03_ID"'"/;}' "$INVENTORY_FILE"
fi

echo ""
echo "=========================================="
echo "Inventory Update Complete"
echo "=========================================="
echo ""
echo "Updated instance IDs:"
grep -A1 "dc01:" "$INVENTORY_FILE" | grep ansible_aws_ssm_instance_id || true
grep -A1 "dc02:" "$INVENTORY_FILE" | grep ansible_aws_ssm_instance_id || true
grep -A1 "dc03:" "$INVENTORY_FILE" | grep ansible_aws_ssm_instance_id || true
echo ""
echo "Verify with: ansible-inventory --list"
echo ""
echo "Next steps:"
echo "  1. Set environment variables:"
echo "     export AD_SAFE_MODE_PASSWORD=\"YourDSRMPassword123\""
echo "     export AD_ADMIN_PASSWORD=\"YourAdminPassword123\""
echo "     export AD_CONNECTOR_PASSWORD=\"YourConnectorPassword123\""
echo ""
echo "  2. Run the playbooks:"
echo "     cd $SCRIPT_DIR"
echo "     ansible-playbook site.yml"
echo ""
