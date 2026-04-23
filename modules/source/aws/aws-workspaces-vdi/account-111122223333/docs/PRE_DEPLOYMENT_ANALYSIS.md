# Pre-Deployment Analysis & Gap Report

**Project:** org-workspaces-vdi  
**Analysis Date:** November 25, 2025  
**Status:** 🔴 **CRITICAL ISSUES FOUND**

---

## 🔴 Critical Issues (Must Fix Before Deployment)

### Issue 1: Remote State Output Name Mismatches

**Problem:** The remote state references expect specific output names that may not exist in the upstream projects.

**Required Outputs from `org-vpc_firewall_us-east-2-account-111122223333`:**
```hcl
output "vpc_id" {}
output "vpc_cidr" {}
output "management_subnet_ids" {}
output "private_subnet_ids" {}
output "all_route_table_ids" {}
output "transit_gateway_id" {}
output "transit_gateway_default_route_table_id" {}  # ⚠️ May not exist
```

**Required Outputs from Manila Landing Zone:**
```hcl
output "vpc_id" {}
output "vpc_cidr" {}
output "management_subnets" {}       # Note: different name than us-east-2
output "vdi1_subnets" {}
output "all_route_table_ids" {}
output "transit_gateway_id" {}
output "transit_gateway_default_route_table_id" {}  # ⚠️ May not exist
```

**Impact:** Terraform will fail during `terraform plan` if these outputs don't exist.

**Resolution:**
1. Verify output names in both upstream projects
2. Update main.tf local values if output names differ
3. Add missing outputs to upstream projects if needed

**Example Fix:**
```hcl
# If the actual output is "default_route_table_id" instead of "transit_gateway_default_route_table_id"
ad_tgw_default_route_table_id = data.terraform_remote_state.vpc_firewall.outputs.default_route_table_id
```

---

### Issue 2: Insufficient Wait Time for AD Replica

**Problem:** AD Replica deployment takes 30+ minutes, but we only wait 10 minutes.

**Current Code (modules/ad-replica/main.tf):**
```hcl
resource "time_sleep" "wait_for_replica" {
  depends_on      = [aws_directory_service_region.replica]
  create_duration = "10m"  # ⚠️ TOO SHORT
}
```

**Impact:** WorkSpaces Directory registration may fail if AD Replica isn't fully operational.

**Resolution:**
```hcl
resource "time_sleep" "wait_for_replica" {
  depends_on      = [aws_directory_service_region.replica]
  create_duration = "35m"  # Increased to ensure replica is fully ready
}
```

---

### Issue 3: WorkSpaces Directory Needs Additional Wait Time

**Problem:** Even after AD Replica is ready, WorkSpaces Directory registration needs the replica to be fully synchronized.

**Current Code:** No wait time between AD Replica and WorkSpaces Directory.

**Impact:** Directory registration might fail with "Directory not ready" error.

**Resolution:** Add wait time in main.tf:
```hcl
# Add after module "ad_replica" and before module "workspaces_directory"
resource "time_sleep" "wait_for_ad_sync" {
  depends_on = [module.ad_replica]
  
  create_duration = "5m"  # Allow time for AD sync
}

# Update workspaces_directory depends_on:
module "workspaces_directory" {
  # ... other config ...
  
  depends_on = [time_sleep.wait_for_ad_sync]
}
```

---

### Issue 4: Unused Variable in workspaces-directory Module

**Problem:** Variable `ad_dns_ips` is defined but never used.

**Current Code:**
```hcl
variable "ad_dns_ips" {
  description = "DNS IP addresses of AD domain controllers"
  type        = list(string)
  default     = []
}
```

**Impact:** None (just cleanup needed), but could cause confusion.

**Resolution:** Remove from module since AWS WorkSpaces automatically gets DNS from Directory Service.

---

## ⚠️ Warning Issues (Should Fix But Not Blocking)

### Warning 1: Network Firewall Rules Not Automated

**Problem:** Network Firewall rules for AD traffic must be manually configured in both regions.

**Required Manual Steps:**
1. Update us-east-2 Network Firewall policy
2. Update ap-southeast-1 Network Firewall policy
3. Add stateful rules for all AD protocols (ports 53, 88, 123, 135, 389, 445, 464, 636, 3268-3269, 49152-65535)

**Impact:** AD replication will fail silently if firewall blocks traffic.

**Testing Command:**
```bash
# Check firewall logs for blocked traffic
aws logs tail /aws/network-firewall/org-firewall --region us-east-2 --follow
aws logs tail /aws/network-firewall/manila-firewall --region ap-southeast-1 --follow
```

---

### Warning 2: WorkSpaces Bundle ID May Not Exist

**Problem:** Default bundle lookup might fail in Manila Local Zone.

**Current Code (modules/workspaces/main.tf):**
```hcl
data "aws_workspaces_bundle" "default" {
  count = var.bundle_id == "" ? 1 : 0
  owner = "AMAZON"
  name  = "Standard with Windows 10 (Server 2019 based)"
}
```

**Impact:** This specific bundle name might not be available in ap-southeast-1.

**Resolution:** Query available bundles first:
```bash
aws workspaces describe-workspace-bundles \
  --region ap-southeast-1 \
  --owner AMAZON \
  --query 'Bundles[].Name'
```

Then update the name in the code or specify a bundle_id in terraform.tfvars.

---

### Warning 3: Subnet Count Validation

**Problem:** WorkSpaces Directory requires exactly 2 subnets, but we're using slice without validation.

**Current Code:**
```hcl
subnet_ids = slice(var.subnet_ids, 0, 2)
```

**Impact:** If Manila VDI subnets list has fewer than 2 subnets, deployment will fail.

**Resolution:** Add validation in main.tf:
```hcl
# Add to local values
validation {
  condition     = length(local.lz_vdi_subnets) >= 2
  error_message = "At least 2 VDI subnets are required for WorkSpaces deployment."
}
```

---

## ✅ Verified Correct Configurations

### 1. Security Groups ✅
- All AD protocols properly configured
- WorkSpaces can communicate with AD Replica
- AD Replica can communicate with Primary AD
- Bidirectional traffic allowed

### 2. Provider Configuration ✅
- Multi-region providers properly configured
- Provider aliases correctly used in modules

### 3. Module Dependencies ✅
- Managed AD → TGW Peering → AD Replica → WorkSpaces Directory → WorkSpaces
- Dependency chain is correct

### 4. Tagging ✅
- Consistent tagging across all resources
- Common tags properly merged

---

## 📋 Pre-Deployment Checklist

### Before Running `terraform init`:

- [ ] **Verify Remote State Buckets Exist:**
  ```bash
  aws s3 ls s3://org-terraform-state-account-111122223333-111122223333/
  aws s3 ls s3://org-terraform-state-account-111122223333-111122223333-ap-southeast-1/
  ```

- [ ] **Verify Upstream Projects Deployed:**
  ```bash
  # Check US-East-2 VPC/Firewall
  aws s3 cp s3://org-terraform-state-account-111122223333-111122223333/us-east-2/account-111122223333/terraform.tfstate - | jq '.outputs | keys'
  
  # Check AP-Southeast-1 Landing Zone
  aws s3 cp s3://org-terraform-state-account-111122223333-111122223333-ap-southeast-1/backend-setup/terraform.tfstate - | jq '.outputs | keys'
  ```

- [ ] **Verify Output Names Match:**
  Compare the actual output names from above commands with what main.tf expects

### Before Running `terraform plan`:

- [ ] **Update terraform.tfvars:**
  - [ ] Add WorkSpaces users (cannot be empty list)
  - [ ] Verify CIDR blocks match deployed infrastructure
  - [ ] Add Azure EntraID credentials (if enabling AD Connect)

- [ ] **Query Available WorkSpaces Bundles:**
  ```bash
  aws workspaces describe-workspace-bundles --region ap-southeast-1 --owner AMAZON
  ```

### Before Running `terraform apply`:

- [ ] **Verify AWS Credentials:**
  ```bash
  aws sts get-caller-identity
  # Should show account 111122223333
  ```

- [ ] **Check Service Limits:**
  ```bash
  # Check if WorkSpaces is enabled in ap-southeast-1
  aws workspaces describe-workspace-directories --region ap-southeast-1
  ```

- [ ] **Verify Network Connectivity:**
  ```bash
  # Check TGW peering is possible
  aws ec2 describe-transit-gateways --region us-east-2
  aws ec2 describe-transit-gateways --region ap-southeast-1
  ```

### After `terraform apply` Completes:

- [ ] **Configure Network Firewall Rules** (CRITICAL)
  - Add AD protocol rules to us-east-2 firewall
  - Add AD protocol rules to ap-southeast-1 firewall

- [ ] **Verify AD Replication:**
  ```bash
  # Wait 10 minutes after deployment, then check
  aws ds describe-directories --region us-east-2
  aws ds describe-directories --region ap-southeast-1
  ```

- [ ] **Test WorkSpaces Connectivity:**
  - Create a test user in AD
  - Provision a WorkSpace for the test user
  - Attempt to connect via WorkSpaces client
  - Verify domain authentication works

---

## 🚨 Deployment Timeline

| Phase | Component | Duration | Critical |
|-------|-----------|----------|----------|
| 1 | Primary Managed AD | ~30 min | ✅ |
| 2 | TGW Peering | ~2 min | ✅ |
| 3 | AD Replica | ~35 min | ✅ |
| 4 | Wait for AD Sync | ~5 min | ⚠️ NEEDED |
| 5 | WorkSpaces Directory | ~5 min | ✅ |
| 6 | WorkSpaces (per user) | ~20 min | ✅ |

**Total Estimated Time:** ~97 minutes + (20 min × number of users)

**⚠️ Important:** Do NOT interrupt the deployment during AD creation or replica deployment. These operations cannot be easily rolled back.

---

## 🔧 Required Code Fixes

### 1. Update modules/ad-replica/main.tf:
```hcl
resource "time_sleep" "wait_for_replica" {
  depends_on      = [aws_directory_service_region.replica]
  create_duration = "35m"  # CHANGED from 10m
}
```

### 2. Update main.tf (add after ad_replica module):
```hcl
# Wait for AD replication to stabilize
resource "time_sleep" "wait_for_ad_sync" {
  depends_on = [module.ad_replica]
  
  create_duration = "5m"
}
```

### 3. Update main.tf (workspaces_directory depends_on):
```hcl
module "workspaces_directory" {
  # ... existing config ...
  
  depends_on = [time_sleep.wait_for_ad_sync]  # CHANGED from [module.ad_replica]
}
```

### 4. Remove unused variable from modules/workspaces-directory/main.tf:
```hcl
# DELETE this variable block:
# variable "ad_dns_ips" {
#   description = "DNS IP addresses of AD domain controllers"
#   type        = list(string)
#   default     = []
# }
```

### 5. Update main.tf (remove ad_dns_ips parameter):
```hcl
module "workspaces_directory" {
  # ... other config ...
  
  # DELETE this line:
  # ad_dns_ips  = module.ad_replica.replica_dns_ips
}
```

---

## 📊 Post-Deployment Validation

### 1. Verify AD Replication:
```powershell
# Connect to Primary AD via SSM
aws ssm start-session --target <dc-instance-id> --region us-east-2

# Check replication status
repadmin /showrepl
repadmin /replsummary
```

### 2. Verify WorkSpaces Authentication:
```powershell
# From a deployed WorkSpace
nltest /dsgetdc:corp.example.internal
nltest /dclist:corp.example.internal

# Should show AD Replica DNS IPs (x.x.x.x)
```

### 3. Check Network Firewall Logs:
```bash
# Look for any blocked AD traffic
aws logs filter-log-events \
  --log-group-name /aws/network-firewall/org-firewall \
  --filter-pattern "REJECT" \
  --region us-east-2
```

---

## 📞 Support & Troubleshooting

**If AD Replication Fails:**
1. Check TGW peering status: `terraform output tgw_peering_status`
2. Verify TGW routes exist in both regions
3. Check Network Firewall logs for blocked traffic
4. Verify security groups allow AD protocols

**If WorkSpaces Can't Join Domain:**
1. Verify AD Replica DNS IPs are reachable from WorkSpaces subnets
2. Check WorkSpaces security group allows outbound AD traffic
3. Verify AD Replica security group allows inbound from WorkSpaces subnets
4. Test DNS resolution from WorkSpaces to corp.example.internal

**If Users Can't Connect:**
1. Verify user exists in Active Directory
2. Check WorkSpaces registration code is correct
3. Verify IP access group allows user's IP address
4. Check WorkSpaces state: `aws workspaces describe-workspaces`

---

## ✅ Ready to Deploy?

**Before proceeding, ensure:**
- ✅ All critical issues are resolved
- ✅ Remote state outputs are verified
- ✅ Upstream projects are fully deployed
- ✅ Network Firewall rules are documented
- ✅ terraform.tfvars is configured with at least one user

**Deployment Command:**
```bash
cd ~/Repos/cloud_infrastructure/org-workspaces-vdi
terraform init
terraform plan -out=tfplan
# Review plan carefully
terraform apply tfplan
```
