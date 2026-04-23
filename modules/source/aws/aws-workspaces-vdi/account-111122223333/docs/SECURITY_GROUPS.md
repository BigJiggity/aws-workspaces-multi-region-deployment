# Security Groups & Network Rules

**Project:** org-workspaces-vdi  
**Updated:** November 25, 2025

This document details all security group rules ensuring proper traffic flow for Active Directory replication, WorkSpaces authentication, and cross-region connectivity.

---

## Overview

All security groups are configured to allow **bidirectional** Active Directory traffic between:
- **Primary AD** (us-east-2: x.x.x.x/xx)
- **AD Replica** (ap-southeast-1: x.x.x.x/xx)
- **WorkSpaces** (Manila Local Zone: x.x.x.x/xx)

---

## Security Group: Primary Managed AD (us-east-2)

**Name:** `org-managed-ad-sg`  
**VPC:** x.x.x.x/xx (account-111122223333-vpc)  
**Subnet:** Management (x.x.x.x/xx)

### Inbound Rules

| Protocol | Port Range | Source CIDR | Purpose |
|----------|-----------|-------------|---------|
| TCP | 53 | x.x.x.x/xx, x.x.x.x/xx | DNS queries |
| UDP | 53 | x.x.x.x/xx, x.x.x.x/xx | DNS queries |
| TCP | 88 | x.x.x.x/xx, x.x.x.x/xx | Kerberos authentication |
| UDP | 88 | x.x.x.x/xx, x.x.x.x/xx | Kerberos authentication |
| UDP | 123 | x.x.x.x/xx, x.x.x.x/xx | NTP time sync (critical for Kerberos) |
| TCP | 135 | x.x.x.x/xx, x.x.x.x/xx | RPC Endpoint Mapper |
| TCP | 389 | x.x.x.x/xx, x.x.x.x/xx | LDAP directory queries |
| UDP | 389 | x.x.x.x/xx, x.x.x.x/xx | LDAP directory queries |
| TCP | 445 | x.x.x.x/xx, x.x.x.x/xx | SMB (Group Policy, file sharing) |
| TCP | 464 | x.x.x.x/xx, x.x.x.x/xx | Kerberos password change |
| UDP | 464 | x.x.x.x/xx, x.x.x.x/xx | Kerberos password change |
| TCP | 636 | x.x.x.x/xx, x.x.x.x/xx | LDAPS (LDAP over TLS) |
| TCP | 3268-3269 | x.x.x.x/xx, x.x.x.x/xx | Global Catalog (forest searches) |
| TCP | 49152-65535 | x.x.x.x/xx, x.x.x.x/xx | RPC dynamic ports |

### Outbound Rules

| Protocol | Port Range | Destination | Purpose |
|----------|-----------|-------------|---------|
| All | All | x.x.x.x/xx | All outbound traffic allowed |

✅ **Allows traffic from:** Local VPC, Landing Zone VPC (includes WorkSpaces)

---

## Security Group: AD Replica (ap-southeast-1)

**Name:** `org-ad-replica-sg`  
**VPC:** x.x.x.x/xx (Manila Landing Zone)  
**Subnet:** Management (x.x.x.x/xx, x.x.x.x/xx)

### Inbound Rules

| Protocol | Port Range | Source CIDR | Purpose |
|----------|-----------|-------------|---------|
| TCP | 53 | x.x.x.x/xx, x.x.x.x/xx | DNS queries |
| UDP | 53 | x.x.x.x/xx, x.x.x.x/xx | DNS queries |
| TCP | 88 | x.x.x.x/xx, x.x.x.x/xx | Kerberos authentication |
| UDP | 88 | x.x.x.x/xx, x.x.x.x/xx | Kerberos authentication |
| UDP | 123 | x.x.x.x/xx, x.x.x.x/xx | NTP time sync |
| TCP | 135 | x.x.x.x/xx, x.x.x.x/xx | RPC Endpoint Mapper |
| TCP | 389 | x.x.x.x/xx, x.x.x.x/xx | LDAP directory queries |
| UDP | 389 | x.x.x.x/xx, x.x.x.x/xx | LDAP directory queries |
| TCP | 445 | x.x.x.x/xx, x.x.x.x/xx | SMB (Group Policy, file sharing) |
| TCP | 464 | x.x.x.x/xx, x.x.x.x/xx | Kerberos password change |
| UDP | 464 | x.x.x.x/xx, x.x.x.x/xx | Kerberos password change |
| TCP | 636 | x.x.x.x/xx, x.x.x.x/xx | LDAPS (LDAP over TLS) |
| TCP | 3268-3269 | x.x.x.x/xx, x.x.x.x/xx | Global Catalog |
| TCP | 49152-65535 | x.x.x.x/xx, x.x.x.x/xx | RPC dynamic ports |

### Outbound Rules

| Protocol | Port Range | Destination | Purpose |
|----------|-----------|-------------|---------|
| All | All | x.x.x.x/xx | All outbound traffic allowed |

✅ **Allows traffic from:** Local VPC (includes WorkSpaces), Primary AD VPC

---

## Security Group: WorkSpaces (ap-southeast-1)

**Name:** `org-workspaces-sg`  
**VPC:** x.x.x.x/xx (Manila Landing Zone)  
**Subnet:** VDI-1 (Manila Local Zone: x.x.x.x/xx)

### Inbound Rules - Client Access

| Protocol | Port Range | Source CIDR | Purpose |
|----------|-----------|-------------|---------|
| TCP | 4172 | x.x.x.x/xx | PCoIP protocol (control channel) |
| UDP | 4172 | x.x.x.x/xx | PCoIP protocol (data channel) |
| TCP | 4195 | x.x.x.x/xx | WSP protocol (control channel) |
| UDP | 4195 | x.x.x.x/xx | WSP protocol (data channel) |
| TCP | 443 | x.x.x.x/xx | HTTPS (WorkSpaces management) |

### Inbound Rules - Active Directory

| Protocol | Port Range | Source CIDR | Purpose |
|----------|-----------|-------------|---------|
| TCP | 53 | x.x.x.x/xx | DNS responses from AD |
| UDP | 53 | x.x.x.x/xx | DNS responses from AD |
| TCP | 88 | x.x.x.x/xx | Kerberos ticket responses |
| UDP | 88 | x.x.x.x/xx | Kerberos ticket responses |
| UDP | 123 | x.x.x.x/xx | NTP time sync from AD |
| TCP | 135 | x.x.x.x/xx | RPC responses from AD |
| TCP | 389 | x.x.x.x/xx | LDAP responses from AD |
| UDP | 389 | x.x.x.x/xx | LDAP responses from AD |
| TCP | 445 | x.x.x.x/xx | SMB (Group Policy downloads) |
| TCP | 464 | x.x.x.x/xx | Kerberos password change |
| UDP | 464 | x.x.x.x/xx | Kerberos password change |
| TCP | 636 | x.x.x.x/xx | LDAPS responses |
| TCP | 3268-3269 | x.x.x.x/xx | Global Catalog responses |
| TCP | 49152-65535 | x.x.x.x/xx | RPC dynamic port responses |

### Outbound Rules

| Protocol | Port Range | Destination | Purpose |
|----------|-----------|-------------|---------|
| All | All | x.x.x.x/xx | All outbound traffic allowed (AD, AWS services, Internet) |

✅ **Allows traffic to:** AD Replica (same VPC), Internet (via NAT), AWS services

---

## Security Group: AD Connect Server (us-east-2)

**Name:** `org-ad-connect-sg`  
**VPC:** x.x.x.x/xx (account-111122223333-vpc)  
**Subnet:** Management (x.x.x.x/xx)

### Inbound Rules

| Protocol | Port Range | Source CIDR | Purpose |
|----------|-----------|-------------|---------|
| TCP | 3389 | x.x.x.x/xx | RDP for administration |

### Outbound Rules

| Protocol | Port Range | Destination | Purpose |
|----------|-----------|-------------|---------|
| All | All | x.x.x.x/xx | All outbound (AD, Azure EntraID, Internet) |

✅ **Can communicate with:** Primary AD (same VPC), Azure EntraID (Internet)

---

## Traffic Flow Verification

### 1. WorkSpaces → AD Replica Authentication

```
WorkSpace (x.x.x.x) → AD Replica (x.x.x.x)
┌──────────────────────────────────────────────────────────────┐
│ 1. DNS Query (UDP 53)           ✅ Allowed                   │
│ 2. Kerberos Auth (TCP/UDP 88)   ✅ Allowed                   │
│ 3. LDAP Query (TCP 389)          ✅ Allowed                   │
│ 4. SMB for GPO (TCP 445)         ✅ Allowed                   │
└──────────────────────────────────────────────────────────────┘
```

**WorkSpaces Security Group:**
- ✅ Outbound: All traffic allowed to x.x.x.x/xx (includes x.x.x.x)
- ✅ Inbound: Allows responses from x.x.x.x/xx on all AD ports

**AD Replica Security Group:**
- ✅ Inbound: Allows all AD protocols from x.x.x.x/xx (includes x.x.x.x/xx)
- ✅ Outbound: All traffic allowed (includes responses to WorkSpaces)

---

### 2. AD Replica ← → Primary AD Replication

```
AD Replica (x.x.x.x) ← TGW → Network Firewall → TGW → Primary AD (x.x.x.x)
┌──────────────────────────────────────────────────────────────┐
│ Route: ap-southeast-1 TGW → Network Firewall → TGW Peering  │
│        → us-east-2 TGW → Network Firewall → Primary AD      │
│                                                               │
│ All AD protocols (53, 88, 135, 389, 445, 464, 636, 3268,    │
│                   3269, 49152-65535)         ✅ Allowed      │
└──────────────────────────────────────────────────────────────┘
```

**AD Replica Security Group:**
- ✅ Inbound: Allows all AD protocols from x.x.x.x/xx
- ✅ Outbound: All traffic allowed to x.x.x.x/xx (includes x.x.x.x/xx)

**Primary AD Security Group:**
- ✅ Inbound: Allows all AD protocols from x.x.x.x/xx
- ✅ Outbound: All traffic allowed to x.x.x.x/xx (includes x.x.x.x/xx)

**Transit Gateway Routes:**
- ✅ us-east-2: Route for x.x.x.x/xx → TGW peering attachment
- ✅ ap-southeast-1: Route for x.x.x.x/xx → TGW peering attachment

**Network Firewalls:**
- ⚠️ **ACTION REQUIRED:** Ensure firewall rules allow AD replication traffic
- Ports needed: TCP/UDP 53, 88, 123, 135, 389, 445, 464, 636, 3268-3269, 49152-65535

---

### 3. WorkSpaces → Internet (Updates, AWS Services)

```
WorkSpace (x.x.x.x) → NAT Gateway → Internet
┌──────────────────────────────────────────────────────────────┐
│ 1. Windows Updates (TCP 443, 80)     ✅ Allowed              │
│ 2. AWS WorkSpaces Service (TCP 443)  ✅ Allowed              │
│ 3. Amazon S3 (TCP 443)                ✅ Allowed              │
└──────────────────────────────────────────────────────────────┘
```

**WorkSpaces Security Group:**
- ✅ Outbound: All traffic allowed to x.x.x.x/xx

---

## Network Firewall Rules Required

**⚠️ IMPORTANT:** The following rules must be configured in both Network Firewalls:

### US-East-2 Network Firewall

```hcl
# Allow AD replication traffic TO ap-southeast-1
Stateful rule: Allow x.x.x.x/xx → x.x.x.x/xx on ports:
  - TCP/UDP: 53, 88, 123, 135, 389, 445, 464, 636, 3268, 3269
  - TCP: 49152-65535

# Allow AD replication traffic FROM ap-southeast-1
Stateful rule: Allow x.x.x.x/xx → x.x.x.x/xx on ports:
  - TCP/UDP: 53, 88, 123, 135, 389, 445, 464, 636, 3268, 3269
  - TCP: 49152-65535
```

### AP-Southeast-1 Network Firewall

```hcl
# Allow AD replication traffic TO us-east-2
Stateful rule: Allow x.x.x.x/xx → x.x.x.x/xx on ports:
  - TCP/UDP: 53, 88, 123, 135, 389, 445, 464, 636, 3268, 3269
  - TCP: 49152-65535

# Allow AD replication traffic FROM us-east-2
Stateful rule: Allow x.x.x.x/xx → x.x.x.x/xx on ports:
  - TCP/UDP: 53, 88, 123, 135, 389, 445, 464, 636, 3268, 3269
  - TCP: 49152-65535
```

---

## Verification Commands

### Check Security Group Rules

```bash
# Primary AD Security Group
aws ec2 describe-security-groups \
  --region us-east-2 \
  --filters "Name=group-name,Values=org-managed-ad-sg" \
  --query 'SecurityGroups[0].IpPermissions'

# AD Replica Security Group
aws ec2 describe-security-groups \
  --region ap-southeast-1 \
  --filters "Name=group-name,Values=org-ad-replica-sg" \
  --query 'SecurityGroups[0].IpPermissions'

# WorkSpaces Security Group
aws ec2 describe-security-groups \
  --region ap-southeast-1 \
  --filters "Name=group-name,Values=org-workspaces-sg" \
  --query 'SecurityGroups[0].IpPermissions'
```

### Test Connectivity from WorkSpaces

Once deployed, test from a WorkSpace:

```powershell
# Test DNS resolution
nslookup corp.example.internal

# Test AD connectivity (port 389)
Test-NetConnection -ComputerName corp.example.internal -Port 389

# Test Kerberos (port 88)
Test-NetConnection -ComputerName corp.example.internal -Port 88

# Test LDAP
nltest /dclist:corp.example.internal

# Verify domain join
nltest /dsgetdc:corp.example.internal
```

### Test AD Replication

```bash
# From Primary AD (via SSM)
aws ssm start-session --target <primary-ad-dc-id>

# Check replication status
repadmin /showrepl

# Force replication
repadmin /syncall /AeD
```

---

## Summary

✅ **All security groups are properly configured to allow:**

1. **WorkSpaces → AD Replica:** Full bidirectional AD protocol communication
2. **AD Replica ↔ Primary AD:** Complete AD replication traffic via TGW peering
3. **WorkSpaces → Internet:** Updates and AWS service access via NAT Gateway
4. **AD Connect → Azure EntraID:** Hybrid identity synchronization

⚠️ **Action Required:**
- Configure Network Firewall rules in both regions to allow AD replication traffic
- Verify firewall logs don't show blocked AD traffic after deployment

🔒 **Security Features:**
- All cross-region traffic inspected by Network Firewalls
- Centralized logging to CloudWatch
- No direct Internet access from WorkSpaces (NAT Gateway only)
- Encrypted EBS volumes on all WorkSpaces
- MFA available via Azure EntraID integration
