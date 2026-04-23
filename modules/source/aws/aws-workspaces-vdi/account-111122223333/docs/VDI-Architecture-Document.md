# Generic WorkSpaces VDI Architecture Document

| **Document Information** | |
|--------------------------|---|
| **Version** | 1.0 |
| **Last Updated** | December 16, 2025 |
| **Owner** | System Architects |
| **Classification** | Internal |
| **AWS Account** | 111122223333 |

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Network Architecture](#3-network-architecture)
4. [Active Directory Architecture](#4-active-directory-architecture)
5. [WorkSpaces Configuration](#5-workspaces-configuration)
6. [Security Architecture](#6-security-architecture)
7. [Storage Architecture](#7-storage-architecture)
8. [High Availability & Disaster Recovery](#8-high-availability--disaster-recovery)
9. [Monitoring & Operations](#9-monitoring--operations)
10. [Cost Analysis](#10-cost-analysis)
11. [Appendix](#11-appendix)

---

## 1. Executive Summary

### 1.1 Purpose

This document describes the architecture of the organization's multi-region AWS WorkSpaces Virtual Desktop Infrastructure (VDI) deployment. The solution provides secure, scalable virtual desktops for users in the United States and Asia-Pacific regions with centralized Active Directory authentication.

### 1.2 Key Highlights

| Metric | Value |
|--------|-------|
| **Regions Deployed** | 2 (us-east-1, ap-southeast-1) |
| **Domain Controllers** | 3 (multi-region) |
| **Active WorkSpaces** | 2 (expandable) |
| **Authentication** | Self-managed Active Directory (example.internal) |
| **Security Model** | Zero Trust with Network Firewall |
| **Infrastructure as Code** | 100% Terraform managed |

### 1.3 Design Principles

- **Zero Trust Security**: All traffic inspected by AWS Network Firewall with drop-by-default policy
- **High Availability**: Multi-AZ deployments with cross-region AD replication
- **Low Latency**: Local domain controllers in each WorkSpaces region
- **Infrastructure as Code**: Complete Terraform automation for reproducibility
- **Cost Optimization**: AUTO_STOP running mode, single NAT gateway per region

---

## 2. Architecture Overview

### 2.1 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    INTERNET                                              │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                    │                                           │
                    │ WorkSpaces Client                         │ WorkSpaces Client
                    │ (US Users)                                │ (Manila Users)
                    ▼                                           ▼
┌───────────────────────────────────────┐     ┌───────────────────────────────────────┐
│         US-EAST-1 (N. Virginia)       │     │      AP-SOUTHEAST-1 (Singapore)       │
│              x.x.x.x/xx               │     │            x.x.x.x/xx                 │
│                                       │     │                                       │
│  ┌─────────────────────────────────┐  │     │  ┌─────────────────────────────────┐  │
│  │     AWS Network Firewall        │  │     │  │     AWS Network Firewall        │  │
│  │     org-use1-firewall           │  │     │  │  manila-landing-pad-firewall    │  │
│  │     (Drop by Default)           │  │     │  │     (Drop by Default)           │  │
│  └─────────────────────────────────┘  │     │  └─────────────────────────────────┘  │
│                  │                    │     │                  │                    │
│  ┌───────────────┴───────────────┐    │     │  ┌───────────────┴───────────────┐    │
│  │                               │    │     │  │                               │    │
│  ▼                               ▼    │     │  ▼                               ▼    │
│ ┌──────────────┐  ┌──────────────┐   │     │ ┌──────────────┐  ┌──────────────┐   │
│ │    DC02      │  │  WorkSpaces  │   │     │ │    DC03      │  │  WorkSpaces  │   │
│ │  x.x.x.x   │  │   testuser   │   │     │ │  x.x.x.x   │  │  rochellec   │   │
│ │  (Local DC)  │  │              │   │     │ │  (Local DC)  │  │              │   │
│ └──────────────┘  └──────────────┘   │     │ └──────────────┘  └──────────────┘   │
│         │                │           │     │         │                │           │
│  ┌──────┴────────────────┴──────┐    │     │  ┌──────┴────────────────┴──────┐    │
│  │       AD Connector           │    │     │  │       AD Connector           │    │
│  │   org-ad-connector-use1      │    │     │  │  org-ad-connector-apse1      │    │
│  └──────────────────────────────┘    │     │  └──────────────────────────────┘    │
│                  │                    │     │                  │                    │
│  ┌───────────────┴───────────────┐    │     │  ┌───────────────┴───────────────┐    │
│  │      Transit Gateway          │    │     │  │      Transit Gateway          │    │
│  │   tgw-019947c7ae3f31028       │    │     │  │   tgw-0877cd6c993b09f29       │    │
│  └───────────────────────────────┘    │     │  └───────────────────────────────┘    │
└───────────────────────────────────────┘     └───────────────────────────────────────┘
                    │                                           │
                    │         TGW Peering (Full Mesh)           │
                    └─────────────────┬─────────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │       US-EAST-2 (Ohio)            │
                    │         x.x.x.x/xx                │
                    │                                   │
                    │  ┌─────────────────────────────┐  │
                    │  │    DC01 (PDC)               │  │
                    │  │    x.x.x.x                │  │
                    │  │    Forest Root             │  │
                    │  │    All FSMO Roles          │  │
                    │  └─────────────────────────────┘  │
                    │                                   │
                    │  ┌─────────────────────────────┐  │
                    │  │   Transit Gateway           │  │
                    │  │   tgw-0dcbbab20d066677a     │  │
                    │  └─────────────────────────────┘  │
                    └───────────────────────────────────┘
```

### 2.2 Component Summary

| Component | US-East-1 | US-East-2 | AP-Southeast-1 |
|-----------|-----------|-----------|----------------|
| **VPC CIDR** | x.x.x.x/xx | x.x.x.x/xx | x.x.x.x/xx |
| **Domain Controller** | DC02 | DC01 (PDC) | DC03 |
| **Network Firewall** | ✓ | ✓ | ✓ |
| **Transit Gateway** | ✓ | ✓ | ✓ |
| **AD Connector** | ✓ | - | ✓ |
| **WorkSpaces** | ✓ | - | ✓ |

### 2.3 Data Flow

1. **User Authentication Flow**
   - User connects via WorkSpaces client
   - WorkSpaces service contacts AD Connector
   - AD Connector authenticates against local DC (DC02 or DC03)
   - Fallback to DC01 via TGW peering if local DC unavailable

2. **Cross-Region Communication**
   - All inter-region traffic traverses Transit Gateway peering
   - Traffic inspected by Network Firewall at source and destination
   - AD replication occurs over TGW peering connections

---

## 3. Network Architecture

### 3.1 VPC Design

#### 3.1.1 US-East-1 (x.x.x.x/xx)

| Subnet Tier | CIDR | AZ | Purpose |
|-------------|------|-----|---------|
| Public | x.x.x.x/xx | us-east-1a | NAT Gateway, Internet Gateway |
| Public | x.x.x.x/xx | us-east-1b | NAT Gateway |
| Private | x.x.x.x/xx | us-east-1a | WorkSpaces |
| Private | x.x.x.x/xx | us-east-1b | WorkSpaces |
| Management | x.x.x.x/xx | us-east-1a | DC02 (x.x.x.x) |
| Management | x.x.x.x/xx | us-east-1b | AD Connector (use1-az2) |
| Management | x.x.x.x/xx | us-east-1c | AD Connector (use1-az4) |
| Inspection | x.x.x.x/xx | us-east-1a | Network Firewall |
| Inspection | x.x.x.x/xx | us-east-1b | Network Firewall |
| TGW | x.x.x.x/xx | us-east-1a | Transit Gateway Attachment |
| TGW | x.x.x.x/xx | us-east-1b | Transit Gateway Attachment |

> **Note**: WorkSpaces in us-east-1 requires subnets in specific AZs (use1-az2, use1-az4, use1-az6). Management subnets [1] and [2] (us-east-1b, us-east-1c) are used for AD Connector and WorkSpaces Directory.

#### 3.1.2 US-East-2 (x.x.x.x/xx)

| Subnet Tier | CIDR | AZ | Purpose |
|-------------|------|-----|---------|
| Public | x.x.x.x/xx | us-east-2a | NAT Gateway |
| Public | x.x.x.x/xx | us-east-2b | NAT Gateway |
| Private | x.x.x.x/xx | us-east-2a | Workloads |
| Private | x.x.x.x/xx | us-east-2b | Workloads |
| Management | x.x.x.x/xx | us-east-2a | DC01 (x.x.x.x) |
| Management | x.x.x.x/xx | us-east-2b | Reserved |
| Inspection | x.x.x.x/xx | us-east-2a | Network Firewall |
| Inspection | x.x.x.x/xx | us-east-2b | Network Firewall |
| TGW | x.x.x.x/xx | us-east-2a | Transit Gateway Attachment |
| TGW | x.x.x.x/xx | us-east-2b | Transit Gateway Attachment |

#### 3.1.3 AP-Southeast-1 (x.x.x.x/xx)

| Subnet Tier | CIDR | AZ | Purpose |
|-------------|------|-----|---------|
| Egress | x.x.x.x/xx | ap-southeast-1a | NAT Gateway |
| Egress | x.x.x.x/xx | ap-southeast-1b | NAT Gateway |
| Egress | x.x.x.x/xx | ap-southeast-1c | NAT Gateway |
| Sandbox | x.x.x.x/xx | ap-southeast-1a | Development |
| Sandbox | x.x.x.x/xx | ap-southeast-1b | Development |
| Management | x.x.x.x/xx | ap-southeast-1a | DC03 (x.x.x.x), AD Connector |
| Management | x.x.x.x/xx | ap-southeast-1b | AD Connector |
| VDI | x.x.x.x/xx | ap-southeast-1a | WorkSpaces |
| VDI | x.x.x.x/xx | ap-southeast-1b | WorkSpaces |
| Inspection | x.x.x.x/xx | ap-southeast-1a | Network Firewall |
| Inspection | x.x.x.x/xx | ap-southeast-1b | Network Firewall |
| TGW | x.x.x.x/xx | ap-southeast-1a | Transit Gateway Attachment |
| TGW | x.x.x.x/xx | ap-southeast-1b | Transit Gateway Attachment |

### 3.2 Transit Gateway Architecture

#### 3.2.1 Transit Gateway Resources

| Region | TGW ID | ASN | Route Table ID |
|--------|--------|-----|----------------|
| us-east-1 | tgw-019947c7ae3f31028 | 64513 | tgw-rtb-0ccab2c5a385c3cc7 |
| us-east-2 | tgw-0dcbbab20d066677a | 64512 | tgw-rtb-06df8087223b965ca |
| ap-southeast-1 | tgw-0877cd6c993b09f29 | 64512 | tgw-rtb-04e5cf4513071c7a6 |

#### 3.2.2 TGW Peering Topology (Full Mesh)

```
                    US-EAST-1
                   (ASN 64513)
                  tgw-019947c7ae3f31028
                       /        \
                      /          \
    tgw-attach-      /            \     tgw-attach-
    03826f46...     /              \    0f37b07f...
                   /                \
              US-EAST-2          AP-SOUTHEAST-1
             (ASN 64512)           (ASN 64512)
        tgw-0dcbbab20d...      tgw-0877cd6c99...
                   \                /
                    \              /
                     \            /
                      tgw-attach-
                      0b92633b...
```

| Peering | Attachment ID | Status |
|---------|---------------|--------|
| us-east-1 ↔ us-east-2 | tgw-attach-03826f462d7457af7 | Active |
| us-east-1 ↔ ap-southeast-1 | tgw-attach-0f37b07f88bf6c708 | Active |
| us-east-2 ↔ ap-southeast-1 | tgw-attach-0b92633becd02e182 | Active |

#### 3.2.3 TGW Route Tables

Each TGW route table contains static routes to all three VPC CIDRs:

| Destination | Target | Notes |
|-------------|--------|-------|
| x.x.x.x/xx | VPC Attachment (local) or Peering | US-East-1 |
| x.x.x.x/xx | VPC Attachment (local) or Peering | US-East-2 |
| x.x.x.x/xx | VPC Attachment (local) or Peering | AP-Southeast-1 |

### 3.3 Routing Architecture

#### 3.3.1 Traffic Flow Pattern

All traffic follows a symmetric path through Network Firewall:

```
Source Subnet → Network Firewall → TGW Subnet → TGW → [Peering] → TGW → TGW Subnet → Network Firewall → Destination Subnet
```

#### 3.3.2 Route Table Design

| Route Table | Destination | Target | Purpose |
|-------------|-------------|--------|---------|
| Private/Management | x.x.x.x/xx | Firewall Endpoint | All traffic via firewall |
| TGW Subnet | 5.x.0.0/16 (internal) | Firewall Endpoint | Prevents asymmetric routing |
| TGW Subnet | x.x.x.x/xx | Firewall Endpoint | Default via firewall |
| Inspection | Peer VPC CIDRs | TGW | Cross-region routing |
| Inspection | x.x.x.x/xx | NAT Gateway | Internet egress |
| Public | x.x.x.x/xx | Internet Gateway | Inbound traffic |

---

## 4. Active Directory Architecture

### 4.1 Domain Configuration

| Property | Value |
|----------|-------|
| **Domain Name** | example.internal |
| **NetBIOS Name** | ORG |
| **Forest Functional Level** | Windows Server 2016 |
| **Domain Functional Level** | Windows Server 2016 |
| **Domain Rebuilt** | December 2025 |

### 4.2 Domain Controllers

| DC | Role | IP Address | Region | AZ | Instance ID |
|----|------|------------|--------|-----|-------------|
| DC01 | PDC, All FSMO Roles | x.x.x.x | us-east-2 | us-east-2a | i-0d74f088f44fc088b |
| DC02 | Secondary DC, DNS, GC | x.x.x.x | us-east-1 | us-east-1a | i-057c205efd2d28087 |
| DC03 | Replica DC, DNS, GC | x.x.x.x | ap-southeast-1 | ap-southeast-1a | i-0f2607ac2de5b1f24 |

### 4.3 AD Sites and Subnets

| Site Name | Subnet | Location |
|-----------|--------|----------|
| US-East-2 | x.x.x.x/xx | Ohio (Primary) |
| US-East-1 | x.x.x.x/xx | N. Virginia |
| AP-Southeast-1 | x.x.x.x/xx | Singapore |

### 4.4 AD Site Links

```
US-East-2 (Primary)
      │
      ├──── Site Link ────► US-East-1
      │     Cost: 100
      │     Replication: 180 min
      │
      └──── Site Link ────► AP-Southeast-1
            Cost: 100
            Replication: 180 min
```

### 4.5 Service Accounts

| Account | Purpose | Password Location |
|---------|---------|-------------------|
| ORG\Administrator | Domain Administration | Secrets Manager |
| svc_adconnector | AD Connector Authentication | Secrets Manager |
| svc_workspaces | WorkSpaces Service | Secrets Manager |

### 4.6 Organizational Units

```
DC=example,DC=internal
├── CN=Users                          # Default users container
├── CN=Computers                      # Default computers container
├── OU=WorkSpaces Computers           # WorkSpaces computer objects
│   └── [GPO: WorkSpaces-LocalAdmins] # Local admin policy
└── OU=Service Accounts               # Service account objects
```

### 4.7 Group Policy Objects

| GPO Name | Linked To | Purpose |
|----------|-----------|---------|
| WorkSpaces-LocalAdmins | OU=WorkSpaces Computers | Grants local admin via Restricted Groups |
| Default Domain Policy | Domain Root | Password policy, security settings |

---

## 5. WorkSpaces Configuration

### 5.1 WorkSpaces Directories

| Region | Directory Type | Directory ID | AD Connector |
|--------|---------------|--------------|--------------|
| us-east-1 | AD Connector | d-xxxxxxxxxx | org-ad-connector-use1 |
| ap-southeast-1 | AD Connector | d-9667a018b7 | org-ad-connector-apse1 |

### 5.2 AD Connector Configuration

#### 5.2.1 US-East-1 AD Connector

| Setting | Value |
|---------|-------|
| **Name** | org-ad-connector-use1 |
| **Size** | Small |
| **Subnets** | x.x.x.x/xx (use1-az2), x.x.x.x/xx (use1-az4) |
| **DNS IPs** | x.x.x.x (DC02), x.x.x.x (DC01) |
| **Service Account** | svc_adconnector |

#### 5.2.2 AP-Southeast-1 AD Connector

| Setting | Value |
|---------|-------|
| **Name** | org-ad-connector-apse1 |
| **Size** | Small |
| **Subnets** | x.x.x.x/xx, x.x.x.x/xx |
| **DNS IPs** | x.x.x.x (DC03), x.x.x.x (DC01) |
| **Service Account** | svc_adconnector |

### 5.3 WorkSpaces Settings

| Setting | Value | Rationale |
|---------|-------|-----------|
| **Running Mode** | AUTO_STOP | Cost optimization |
| **Auto Stop Timeout** | 1 hour | Default |
| **Compute Type** | STANDARD | General purpose |
| **Root Volume** | 80 GB | Windows + applications |
| **User Volume** | 50 GB | User data |
| **Encryption** | Disabled | Allows imaging/snapshots |
| **Default OU** | OU=WorkSpaces Computers,DC=example,DC=internal | GPO application |

### 5.4 IP Access Control

| Setting | Value |
|---------|-------|
| **IP Group** | Allow All (x.x.x.x/xx) |
| **Trusted Devices** | Not configured |

> **Note**: Network-level access control is handled by AWS Network Firewall at the VPC perimeter.

### 5.5 Current WorkSpaces Inventory

| User | Region | WorkSpace ID | State | Compute |
|------|--------|--------------|-------|---------|
| testuser | us-east-1 | ws-xxxxxxxxx | AVAILABLE | STANDARD |
| rochellec | ap-southeast-1 | ws-3dnlbwkc7 | AVAILABLE | STANDARD |

---

## 6. Security Architecture

### 6.1 Zero Trust Model

The VDI infrastructure implements a Zero Trust security model:

```
┌─────────────────────────────────────────────────────────────────┐
│                     ZERO TRUST PRINCIPLES                        │
├─────────────────────────────────────────────────────────────────┤
│ 1. Never Trust, Always Verify                                   │
│    - All traffic inspected by Network Firewall                  │
│    - No implicit trust even within VPC                          │
│                                                                  │
│ 2. Least Privilege Access                                       │
│    - Security groups limit port access                          │
│    - Service accounts with minimal permissions                  │
│                                                                  │
│ 3. Assume Breach                                                │
│    - Fail-closed routing (blackhole if firewall unavailable)   │
│    - Network segmentation between tiers                         │
│                                                                  │
│ 4. Verify Explicitly                                            │
│    - AD authentication for all WorkSpaces access                │
│    - MFA capability (not currently enabled)                     │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Network Firewall Configuration

#### 6.2.1 Firewall Resources

| Region | Firewall Name | Policy |
|--------|---------------|--------|
| us-east-1 | org-use1-firewall | Drop by Default |
| us-east-2 | org-account-111122223333-firewall | Drop by Default |
| ap-southeast-1 | manila-landing-pad-firewall | Drop by Default |

#### 6.2.2 Rule Groups (Priority Order)

| Priority | Rule Group | Type | Purpose |
|----------|------------|------|---------|
| 50 | mgmt-bypass | Stateful | Management subnet unrestricted + peer VPC access |
| 100 | domain-allow | Stateful | HTTPS domain allowlist |
| 200 | inter-subnet | Stateful | AD protocols, WorkSpaces streaming |
| Default | DROP | - | All unmatched traffic dropped |

#### 6.2.3 Allowed Protocols

**AD Protocols:**

| Protocol | Port | Description |
|----------|------|-------------|
| Kerberos | 88 TCP/UDP | Authentication |
| RPC | 135 TCP | Remote Procedure Call |
| NetBIOS | 137-139 TCP/UDP | Legacy name resolution |
| LDAP | 389 TCP/UDP | Directory queries |
| SMB | 445 TCP | File sharing, Group Policy |
| LDAPS | 636 TCP | Secure LDAP |
| Global Catalog | 3268-3269 TCP | Forest-wide queries |
| RPC Dynamic | 49152-65535 TCP | AD replication |

**WorkSpaces Protocols:**

| Protocol | Port | Description |
|----------|------|-------------|
| PCoIP | 4172 TCP/UDP | WorkSpaces streaming |
| WSP | 4195 TCP/UDP | WorkSpaces streaming (alternative) |

### 6.3 Security Groups

#### 6.3.1 Domain Controller Security Group

| Direction | Protocol | Port | Source/Destination | Purpose |
|-----------|----------|------|-------------------|---------|
| Inbound | TCP/UDP | 53 | x.x.x.x/xx | DNS |
| Inbound | TCP/UDP | 88 | x.x.x.x/xx | Kerberos |
| Inbound | TCP | 135 | x.x.x.x/xx | RPC |
| Inbound | TCP/UDP | 389 | x.x.x.x/xx | LDAP |
| Inbound | TCP | 445 | x.x.x.x/xx | SMB |
| Inbound | TCP | 636 | x.x.x.x/xx | LDAPS |
| Inbound | TCP | 3268-3269 | x.x.x.x/xx | Global Catalog |
| Inbound | TCP | 3389 | x.x.x.x/xx | RDP |
| Inbound | TCP | 5985-5986 | x.x.x.x/xx | WinRM |
| Inbound | TCP | 49152-65535 | x.x.x.x/xx | RPC Dynamic |
| Outbound | All | All | x.x.x.x/xx | All traffic |

### 6.4 Encryption

| Component | Encryption | Notes |
|-----------|------------|-------|
| Terraform State | SSE-S3 | S3 bucket encryption |
| Secrets Manager | AWS KMS | Credential storage |
| EBS Volumes (DCs) | Not encrypted | Consider enabling |
| WorkSpaces Volumes | Not encrypted | Allows imaging |
| Network Traffic | IPSec (TGW) | Cross-region encryption |

### 6.5 Credential Management

All credentials are stored securely in AWS Secrets Manager. **Never store credentials in documentation, code, or configuration files.**

#### 6.5.1 Secrets Inventory

| Secret Name | Region | Contents |
|-------------|--------|----------|
| org-infrastructure/credentials | us-east-2 | AD admin, service accounts |
| org-workspaces-s3-sync-credentials | us-east-2 | S3 access key/secret for rclone |

#### 6.5.2 Retrieving Credentials

**AD Administrator Password:**
```bash
aws secretsmanager get-secret-value --region us-east-2 \
  --secret-id org-infrastructure/credentials \
  --query 'SecretString' --output text | jq -r '.administrator_password'
```

**AD Connector Service Account Password:**
```bash
aws secretsmanager get-secret-value --region us-east-2 \
  --secret-id org-infrastructure/credentials \
  --query 'SecretString' --output text | jq -r '.svc_adconnector_password'
```

**S3 Sync Credentials (for rclone):**
```bash
# Get Access Key ID
aws secretsmanager get-secret-value --region us-east-2 \
  --secret-id org-workspaces-s3-sync-credentials \
  --query 'SecretString' --output text | jq -r '.access_key_id'

# Get Secret Access Key
aws secretsmanager get-secret-value --region us-east-2 \
  --secret-id org-workspaces-s3-sync-credentials \
  --query 'SecretString' --output text | jq -r '.secret_access_key'
```

> **Security Note**: Credentials should only be retrieved when needed and never logged, displayed on screen in shared environments, or stored in plain text files.

---

## 7. Storage Architecture

### 7.1 S3 Installers Bucket

| Property | Value |
|----------|-------|
| **Bucket Name** | org-workspace-vdi-installs |
| **Region** | ap-southeast-1 |
| **Purpose** | Software installers for WorkSpaces |
| **Mount Point** | S: drive via rclone |

### 7.2 Rclone Configuration

WorkSpaces mount the S3 bucket as a network drive using rclone:

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│   WorkSpace     │      │   AWS S3         │      │   Admin Upload  │
│   (S: Drive)    │◄────►│   Bucket         │◄─────│   (aws s3 cp)   │
│   rclone mount  │      │   org-workspace- │      │                 │
│                 │      │   vdi-installs   │      │                 │
└─────────────────┘      └──────────────────┘      └─────────────────┘
```

**Rclone Service Configuration:**

- **Service Name**: RcloneS3Mount
- **Startup Type**: Automatic (via Scheduled Task)
- **Run As**: SYSTEM
- **Cache Mode**: vfs-cache-mode full

### 7.3 Terraform State Storage

| Component | Value |
|-----------|-------|
| **S3 Bucket** | org-terraform-state-account-111122223333-111122223333 |
| **DynamoDB Table** | org-terraform-state-account-111122223333 |
| **Region** | us-east-2 |
| **Encryption** | SSE-S3 |
| **Versioning** | Enabled |

---

## 8. High Availability & Disaster Recovery

### 8.1 Availability Design

| Component | HA Strategy | RPO | RTO |
|-----------|-------------|-----|-----|
| Domain Controllers | Multi-region replication | 15 min | 5 min (failover) |
| AD Connector | Multi-AZ deployment | N/A | Automatic |
| WorkSpaces | Single AZ | 12 hours | 30 min (rebuild) |
| Network Firewall | Multi-AZ endpoints | N/A | Automatic |
| Transit Gateway | Regional service | N/A | Automatic |

### 8.2 Domain Controller Failover

```
Normal Operation:
┌─────────────────┐     ┌─────────────────┐
│   WorkSpaces    │────►│   Local DC      │
│   us-east-1     │     │   DC02          │
└─────────────────┘     └─────────────────┘

Failover (DC02 unavailable):
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   WorkSpaces    │────►│   AD Connector  │────►│   DC01 (PDC)    │
│   us-east-1     │     │   (Fallback)    │     │   us-east-2     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### 8.3 Disaster Recovery Procedures

#### 8.3.1 DC Failure Recovery

1. AD Connector automatically fails over to secondary DNS IP
2. Monitor AD replication health via `repadmin /replsummary`
3. Rebuild failed DC from Terraform + Ansible

#### 8.3.2 WorkSpace Recovery

1. WorkSpaces can be rebuilt from bundle
2. User data on D: drive is preserved (user volume)
3. S3 mount reconfiguration required after rebuild

### 8.4 Backup Strategy

| Component | Backup Method | Frequency | Retention |
|-----------|--------------|-----------|-----------|
| AD (System State) | Windows Server Backup | Daily | 30 days |
| Terraform State | S3 Versioning | Per change | 90 days |
| Secrets Manager | Automatic | Continuous | 30 days |
| WorkSpaces User Volume | AWS Snapshots | Not configured | - |

---

## 9. Monitoring & Operations

### 9.1 CloudWatch Metrics

| Service | Key Metrics |
|---------|-------------|
| WorkSpaces | ConnectionAttempt, ConnectionSuccess, ConnectionFailure |
| Network Firewall | DroppedPackets, PassedPackets |
| EC2 (DCs) | CPUUtilization, NetworkIn/Out, StatusCheckFailed |

### 9.2 CloudWatch Alarms (Recommended)

| Alarm | Threshold | Action |
|-------|-----------|--------|
| DC CPU High | > 80% for 5 min | SNS notification |
| DC Status Check Failed | Any failure | SNS notification |
| Firewall Dropped Packets | > 1000/min | SNS notification |
| WorkSpaces Connection Failures | > 10/hour | SNS notification |

### 9.3 Log Locations

| Log Type | Location |
|----------|----------|
| Network Firewall Alert | CloudWatch: /aws/network-firewall/{firewall}/alert |
| Network Firewall Flow | CloudWatch: /aws/network-firewall/{firewall}/flow |
| AD Event Logs | Windows Event Viewer on DCs |
| WorkSpaces Access | CloudWatch: /aws/workspaces/{directory-id} |

### 9.4 Operational Runbooks

| Runbook | Location |
|---------|----------|
| User Provisioning | docs/RUNBOOK-User-Provisioning.md |
| DC Recovery | ansible/playbooks/README.md |
| Network Troubleshooting | org-aws-networking/README.md |

---

## 10. Cost Analysis

### 10.1 Monthly Cost Estimate

| Component | Quantity | Unit Cost | Monthly Cost |
|-----------|----------|-----------|--------------|
| **Domain Controllers** | | | |
| EC2 (t3.medium) | 3 | $30/mo | $90 |
| EBS (50GB gp3) | 3 | $4/mo | $12 |
| **Networking** | | | |
| NAT Gateway | 3 | $32/mo | $96 |
| NAT Gateway Data | ~100GB | $0.045/GB | $14 |
| Network Firewall | 3 | $275/mo | $825 |
| TGW Attachments | 6 | $36/mo | $216 |
| TGW Peering | 3 | $0/mo | $0 |
| Route53 Resolver | 4 endpoints | $90/mo | $360 |
| **WorkSpaces** | | | |
| WorkSpaces (STANDARD, AUTO_STOP) | 2 | $21/mo + $0.17/hr | ~$60 |
| **Storage** | | | |
| S3 (Installers) | ~10GB | $0.023/GB | $1 |
| S3 (Terraform State) | ~1GB | $0.023/GB | $1 |
| Secrets Manager | 2 secrets | $0.40/mo | $1 |
| **TOTAL** | | | **~$1,676/mo** |

### 10.2 Cost Optimization Opportunities

| Opportunity | Potential Savings | Implementation |
|-------------|-------------------|----------------|
| Reserved Instances (DCs) | 30-40% on EC2 | 1-year commitment |
| Single NAT Gateway per region | $192/mo | Already implemented |
| AUTO_STOP WorkSpaces | Variable | Already implemented |
| Savings Plans | 20-30% on compute | Evaluate usage patterns |

---

## 11. Appendix

### 11.1 Terraform Project Structure

```
cloud_infrastructure/
├── org-aws-networking/
│   └── account-111122223333/
│       ├── modules/
│       │   ├── vpc/
│       │   ├── subnets/
│       │   ├── network-firewall/
│       │   ├── transit-gateway/
│       │   └── tgw-peering/
│       ├── us-east-1/
│       ├── us-east-2/
│       └── ap-southeast-1/
├── org-aws-ActiveDirectory/
│   └── account-111122223333/
│       ├── main.tf
│       ├── ansible/
│       │   └── playbooks/
│       └── README.md
└── org-workspaces-vdi/
    └── account-111122223333/
        ├── modules/
        │   ├── ad-connector/
        │   ├── workspaces/
        │   └── workspaces-directory/
        ├── us-east-1/
        ├── ap-southeast-1/
        └── docs/
```

### 11.2 Key Resource IDs

#### Domain Controllers

| Resource | ID |
|----------|-----|
| DC01 Instance | i-0d74f088f44fc088b |
| DC02 Instance | i-057c205efd2d28087 |
| DC03 Instance | i-0f2607ac2de5b1f24 |

#### Transit Gateways

| Resource | ID |
|----------|-----|
| US-East-1 TGW | tgw-019947c7ae3f31028 |
| US-East-2 TGW | tgw-0dcbbab20d066677a |
| AP-Southeast-1 TGW | tgw-0877cd6c993b09f29 |

#### VPCs

| Resource | ID |
|----------|-----|
| US-East-2 VPC | vpc-066b5d5ade267680f |
| AP-Southeast-1 VPC | vpc-0c084be0ef4b0fe7f |

### 11.3 Contact Information

| Role | Contact |
|------|---------|
| System Architects | system-architects@example.com |
| Cloud Infrastructure | cloud-infra@example.com |

### 11.4 Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | December 16, 2025 | System Architects | Initial release |
| 1.1 | December 16, 2025 | System Architects | Removed hardcoded credentials, added Secrets Manager retrieval instructions |

### 11.5 Related Documents

| Document | Location |
|----------|----------|
| Networking README | org-aws-networking/.../README.md |
| AD README | org-aws-ActiveDirectory/.../README.md |
| VDI README | org-workspaces-vdi/.../README.md |
| User Provisioning Runbook | org-workspaces-vdi/.../docs/RUNBOOK-User-Provisioning.md |

---

*This document is maintained as Infrastructure as Code documentation and should be updated whenever architectural changes are made to the VDI infrastructure.*
