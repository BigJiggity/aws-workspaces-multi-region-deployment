# Critical Deployment Issues Analysis

**Project:** org-workspaces-vdi  
**Analysis Date:** November 25, 2025  
**Status:** 🔴 **CRITICAL ISSUES FOUND - DO NOT DEPLOY**

---

## 🔴 CRITICAL ISSUES (Deployment Blockers)

### 1. Output Name Mismatch in WorkSpaces Module

**Severity:** CRITICAL - Will cause Terraform error  
**Location:** `outputs.tf` lines 136-148  
**Issue:**

Root module references:
```hcl
output "workspaces_ids" {
  value = module.workspaces.workspace_ids  # ❌ WRONG
}

output "workspaces_computer_names" {
  value = module.workspaces.workspace_computer_names  # ❌ WRONG
}

output "workspaces_ip_addresses" {
  value = module.workspaces.workspace_ip_addresses  # ❌ WRONG
}
```

But WorkSpaces module outputs are named:
```hcl
output "workspace_ids" { }      # Note: singular "workspace"
output "computer_names" { }     # Note: no "workspace_" prefix
output "ip_addresses" { }       # Note: no "workspace_" prefix
```

**Fix Required:**
```hcl
# Change in outputs.tf:
output "workspaces_ids" {
  value = module.workspaces.workspace_ids  # workspace_ids (no 's')
}

output "workspaces_computer_names" {
  value = module.workspaces.computer_names  # Just computer_names
}

output "workspaces_ip_addresses" {
  value = module.workspaces.ip_addresses  # Just ip_addresses
}
```

---

### 2. Landing Zone Remote State Key May Be Incorrect

**Severity:** CRITICAL - Remote state won't be found  
**Location:** `terraform.tfvars` line 18  
**Issue:**

```hcl
landing_zone_state_key = "backend-setup/terraform.tfstate"
```

This looks like a backend infrastructure state, NOT the Manila Landing Zone VPC state.

**Expected key should be something like:**
- `ap-southeast-1/manila-landing-zone/terraform.tfstate`
- `manila-vdi-landing-pad/terraform.tfstate`
- Or whatever the actual Landing Zone project uses

**Impact:** 
- All `local.lz_*` variables will fallback to empty values
- AD Replica will fail (no subnet IDs)
- WorkSpaces will fail (no VDI subnet IDs)
- TGW peering will fail (no TGW ID)

**Action Required:**
Verify the actual state key for the Manila Landing Zone project and update `terraform.tfvars`.

---

### 3. WorkSpaces Will Not Resolve Domain DNS

**Severity:** CRITICAL - WorkSpaces won't be able to join domain  
**Location:** `modules/workspaces-directory/main.tf`  
**Issue:**

WorkSpaces need custom DNS to resolve `corp.example.internal` to AD Replica IPs, but:
- `workspaces-directory` module receives `ad_dns_ips` parameter
- **But doesn't use it anywhere!**
- WorkSpaces will use default VPC DNS which won't know about corp.example.internal

**Current code:**
```hcl
variable "ad_dns_ips" {
  description = "DNS IP addresses of AD domain controllers"
  type        = list(string)
  default     = []
}

# ❌ Variable is defined but NEVER USED in the module
```

**Fix Required:**

WorkSpaces Directory doesn't support custom DNS directly. We need to:
1. Create Route53 Private Hosted Zone for `corp.example.internal`
2. Associate it with Landing Zone VPC
3. Create A records pointing to AD Replica DNS IPs

OR

Configure DHCP options for the VPC to use AD Replica as DNS servers (but this affects entire VPC).

**This is a CRITICAL issue** - without DNS resolution, WorkSpaces cannot join the domain.

---

### 4. AD Replica May Not Be Fully Synced

**Severity:** HIGH - WorkSpaces may fail to join domain  
**Location:** `modules/ad-replica/main.tf` line 232  
**Issue:**

```hcl
resource "time_sleep" "wait_for_replica" {
  depends_on      = [aws_directory_service_region.replica]
  create_duration = "10m"  # ❌ Too short!
}
```

AWS Managed AD replication typically takes **30-45 minutes** to fully establish:
- Initial replica creation: ~10 minutes
- AD replication sync: ~20-30 minutes additional
- DNS propagation: ~5 minutes

**Impact:**
- WorkSpaces Directory registration may succeed but WorkSpaces fail to join
- Users can't authenticate until replication completes

**Fix Required:**
```hcl
create_duration = "45m"  # Give ample time for full replication
```

---

### 5. Manila Local Zone Bundle Availability

**Severity:** HIGH - WorkSpaces deployment may fail  
**Location:** `modules/workspaces/main.tf` lines 44-48  
**Issue:**

```hcl
data "aws_workspaces_bundle" "default" {
  count = var.bundle_id == "" ? 1 : 0
  owner = "AMAZON"
  name  = "Standard with Windows 10 (Server 2019 based)"
}
```

**Manila Local Zone (ap-southeast-1-mnl-1a) may not have all AWS bundles available.**

Local Zones have limited service availability. The bundle lookup may fail.

**Fix Required:**
1. Pre-query available bundles in Manila Local Zone:
   ```bash
   aws workspaces describe-workspace-bundles \
     --region ap-southeast-1 \
     --owner AMAZON \
     --query 'Bundles[?contains(ComputeType.Name, `STANDARD`)]'
   ```

2. Hardcode a known-good bundle ID for Manila Local Zone in `terraform.tfvars`

**Action:** Verify bundle availability BEFORE deployment.

---

## ⚠️ HIGH-RISK ISSUES (May Cause Operational Failures)

### 6. No User Creation Mechanism

**Severity:** HIGH - WorkSpaces won't deploy without users  
**Issue:**

```hcl
workspaces_users = []  # Empty by default
```

- Users must exist in AD BEFORE creating WorkSpaces
- No mechanism to create AD users via Terraform
- Manual step required in Directory Service console or via AD tools

**Workflow Required:**
1. Deploy Managed AD
2. Wait for deployment (~30 min)
3. Retrieve admin password from Secrets Manager
4. Create users via:
   - AWS Directory Service console "Create user"
   - AD Connect server (after it joins domain)
   - PowerShell via SSM to AD Connect server
5. Update `terraform.tfvars` with usernames
6. Run `terraform apply` again for WorkSpaces

**Documentation Required:**
Create a user provisioning guide.

---

### 7. WorkSpaces Subnet Requirements Not Validated

**Severity:** MEDIUM - Deployment may fail  
**Location:** `modules/workspaces-directory/main.tf` line 291  
**Issue:**

```hcl
subnet_ids = slice(var.subnet_ids, 0, 2)
```

WorkSpaces Directory requires:
- **Exactly 2 subnets**
- **In different Availability Zones**
- **With proper routing to NAT Gateway**

But Manila Local Zone only has **1 AZ: ap-southeast-1-mnl-1a**.

**This is a potential blocker!**

WorkSpaces in Local Zones may have special requirements. Need to verify if:
1. WorkSpaces can run in single-AZ configuration in Local Zones
2. If so, the subnet_ids slice needs to handle single subnet

**Action Required:**
Check AWS documentation for WorkSpaces in Local Zones requirements.

---

### 8. Network Firewall Rules Not Configured

**Severity:** HIGH - AD replication will be blocked  
**Issue:**

Security groups are correct, but **Network Firewalls in both regions will block all cross-region traffic by default.**

**Required Actions:**

#### US-East-2 Firewall (`org-use2-account-111122223333-firewall`):
```hcl
# Add stateful rule group
resource "aws_networkfirewall_rule_group" "ad_replication_use2" {
  capacity = 100
  name     = "allow-ad-replication-to-manila"
  type     = "STATEFUL"
  
  rule_group {
    stateful_rule {
      action = "PASS"
      header {
        destination      = "x.x.x.x/xx"
        destination_port = "ANY"
        protocol         = "TCP"
        source           = "x.x.x.x/xx"
        source_port      = "ANY"
      }
      rule_option {
        keyword = "sid:1"
      }
    }
    # Add similar rules for UDP
  }
}
```

#### AP-Southeast-1 Firewall (`account-111122223333-firewall`):
Similar rules allowing x.x.x.x/xx ↔ x.x.x.x/xx

**Without these rules, AD replication will fail!**

---

### 9. Workspaces Computer Names May Exceed Length

**Severity:** LOW - May cause registration issues  
**Issue:**

WorkSpaces computer name format: `org-workspace-{username}`

If username is long (e.g., "christopher.williamson"), computer name could exceed Windows 15-character NetBIOS limit.

**Fix:**
Truncate username in naming:
```hcl
Name = "org-ws-${substr(each.value, 0, 10)}"
```

---

### 10. No VPC DNS Configuration Verification

**Severity:** MEDIUM  
**Issue:**

Landing Zone VPC must have:
- `enable_dns_hostnames = true`
- `enable_dns_support = true`

These are required for WorkSpaces to function. Not validated in code.

---

## 📋 PRE-DEPLOYMENT CHECKLIST

Before running `terraform apply`:

### Prerequisites
- [ ] Verify VPC/Firewall project deployed in us-east-2
- [ ] Verify Landing Zone project deployed in ap-southeast-1
- [ ] Confirm correct remote state key for Landing Zone
- [ ] Verify Manila Local Zone WorkSpaces bundle availability

### Network Configuration
- [ ] Configure Network Firewall rules in us-east-2 for cross-region traffic
- [ ] Configure Network Firewall rules in ap-southeast-1 for cross-region traffic
- [ ] Verify TGW routes exist in both regions
- [ ] Verify Landing Zone VPC has DNS enabled

### DNS Resolution
- [ ] **CRITICAL:** Implement DNS solution for corp.example.internal resolution
  - Option A: Route53 Private Hosted Zone (recommended)
  - Option B: Custom DHCP options set
- [ ] Test DNS resolution from Landing Zone VPC

### User Management
- [ ] Document user creation process
- [ ] Plan initial user list
- [ ] Prepare user creation scripts/documentation

### Timing
- [ ] Plan for 30-minute AD deployment wait
- [ ] Plan for 45-minute AD replica sync wait
- [ ] Plan for 20-minute per WorkSpace deployment

### Post-Deployment
- [ ] Test WorkSpace connectivity from client
- [ ] Verify domain join successful
- [ ] Test user login to WorkSpace
- [ ] Verify AD replication status
- [ ] Check CloudWatch logs for errors

---

## 🔧 IMMEDIATE FIXES REQUIRED

### Fix 1: Output Names (outputs.tf)
```hcl
output "workspaces_ids" {
  description = "Map of username to WorkSpaces instance ID"
  value       = module.workspaces.workspace_ids  # Changed
}

output "workspaces_computer_names" {
  description = "Map of username to WorkSpaces computer name"
  value       = module.workspaces.computer_names  # Changed
}

output "workspaces_ip_addresses" {
  description = "Map of username to WorkSpaces IP address"
  value       = module.workspaces.ip_addresses  # Changed
}
```

### Fix 2: AD Replica Wait Time (modules/ad-replica/main.tf)
```hcl
resource "time_sleep" "wait_for_replica" {
  depends_on      = [aws_directory_service_region.replica]
  create_duration = "45m"  # Increased from 10m
}
```

### Fix 3: DNS Resolution (NEW MODULE REQUIRED)
Create `modules/dns-resolver/main.tf`:
```hcl
# Route53 Private Hosted Zone for corp.example.internal
resource "aws_route53_zone" "corp_ssl" {
  name = var.domain_name

  vpc {
    vpc_id     = var.vpc_id
    vpc_region = var.region
  }

  tags = var.tags
}

# A records for AD Replica domain controllers
resource "aws_route53_record" "ad_replica" {
  count   = length(var.ad_dns_ips)
  zone_id = aws_route53_zone.corp_ssl.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [var.ad_dns_ips[count.index]]
}
```

---

## 💰 COST ESTIMATE

Based on current configuration:

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| Managed AD (Primary) | $292 | Enterprise edition |
| AD Replica | $292 | Enterprise edition |
| AD Connect (t3.medium) | $30 | 24/7 operation |
| NAT Gateways (2x) | $65 | us-east-2 + ap-southeast-1 |
| TGW Data Transfer | $20-50 | Cross-region replication |
| Network Firewall (2x) | $570 | ~$285 per region |
| WorkSpaces (0 users) | $0 | No users configured |
| **TOTAL** | **~$1,269/month** | Without WorkSpaces users |

**Per WorkSpace (AUTO_STOP):** $7.25/month + $0.28/hour  
**Per WorkSpace (ALWAYS_ON Standard):** ~$35/month

---

## ⏱️ ESTIMATED DEPLOYMENT TIME

| Phase | Duration | Notes |
|-------|----------|-------|
| Managed AD Creation | 30 min | Automated |
| TGW Peering Setup | 2 min | Automated |
| AD Replica Creation | 10 min | Automated |
| **AD Replication Sync** | **30-40 min** | **Manual wait** |
| WorkSpaces Directory | 5 min | Automated |
| WorkSpaces (per user) | 20 min | Parallel deployment |
| **TOTAL (no users)** | **~77 min** | **Plus manual steps** |

---

## 🚨 RECOMMENDATION

**DO NOT DEPLOY** until the following are resolved:

1. ✅ Fix output name mismatches
2. ✅ Verify Landing Zone remote state key
3. ❌ Implement DNS resolution for WorkSpaces (Route53 or DHCP)
4. ✅ Increase AD replica wait time
5. ❌ Configure Network Firewall rules in both regions
6. ❌ Verify Manila Local Zone WorkSpaces bundle availability
7. ❌ Create user provisioning documentation
8. ❌ Verify WorkSpaces subnet requirements for Local Zones

**Priority Order:**
1. DNS resolution (#3) - CRITICAL BLOCKER
2. Remote state key (#2) - CRITICAL BLOCKER  
3. Output names (#1) - Terraform error
4. Network Firewall rules (#5) - AD replication failure
5. Everything else

Estimated time to fix all issues: **4-6 hours**
