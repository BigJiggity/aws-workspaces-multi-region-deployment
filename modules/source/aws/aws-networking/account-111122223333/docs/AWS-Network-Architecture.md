# AWS account-111122223333 Account Network Architecture

| Document Information |  |
|---|---|
| Version | 1.0 |
| Last Updated | December 16, 2025 |
| AWS Account | 111122223333 |
| Classification | Internal |
| Owner | Platform Engineering |

---

# 1. Executive Summary

This document describes the network architecture deployed in AWS account 111122223333 (account-111122223333 Account). The architecture implements a multi-region hub-and-spoke topology connecting three AWS regions via Transit Gateway peering, with centralized Network Firewall inspection in each region following a Zero Trust security model.

**Key Characteristics:**

| Attribute | Value |
|---|---|
| Regions | us-east-1, us-east-2, ap-southeast-1 |
| Total VPCs | 3 |
| IP Address Space | x.x.x.x/xx (Class A allocation) |
| Inter-Region Connectivity | Transit Gateway Peering (full mesh) |
| Security Model | Drop-by-default Network Firewall |
| Traffic Inspection | 100% east-west and north-south traffic |

---

# 2. Network Topology Overview

## 2.1 High-Level Architecture

```
                                    ┌─────────────────────────────────────────┐
                                    │              INTERNET                    │
                                    └─────────────────────────────────────────┘
                                                      │
            ┌─────────────────────────────────────────┼─────────────────────────────────────────┐
            │                                         │                                         │
            ▼                                         ▼                                         ▼
┌───────────────────────┐             ┌───────────────────────┐             ┌───────────────────────┐
│     US-EAST-2         │             │     US-EAST-1         │             │   AP-SOUTHEAST-1      │
│     (Ohio)            │             │   (N. Virginia)       │             │    (Singapore)        │
│                       │             │                       │             │                       │
│  VPC: x.x.x.x/xx      │             │  VPC: x.x.x.x/xx      │             │  VPC: x.x.x.x/xx      │
│                       │             │                       │             │                       │
│  ┌─────────────────┐  │             │  ┌─────────────────┐  │             │  ┌─────────────────┐  │
│  │ Network Firewall│  │             │  │ Network Firewall│  │             │  │ Network Firewall│  │
│  │ (org-account-111122223333 │  │             │  │ (org-use1-      │  │             │  │ (manila-landing │  │
│  │  -firewall)     │  │             │  │  firewall)      │  │             │  │  -pad-firewall) │  │
│  └────────┬────────┘  │             │  └────────┬────────┘  │             │  └────────┬────────┘  │
│           │           │             │           │           │             │           │           │
│  ┌────────┴────────┐  │             │  ┌────────┴────────┐  │             │  ┌────────┴────────┐  │
│  │ Transit Gateway │  │◄───────────►│  │ Transit Gateway │  │◄───────────►│  │ Transit Gateway │  │
│  │ tgw-0dcbbab20...│  │   Peering   │  │ tgw-019947c7...│  │   Peering   │  │ tgw-0877cd6c...│  │
│  │ ASN: 64512      │  │             │  │ ASN: 64513      │  │             │  │ ASN: 64512      │  │
│  └─────────────────┘  │             │  └─────────────────┘  │             │  └─────────────────┘  │
│                       │             │                       │             │                       │
│  Purpose:             │             │  Purpose:             │             │  Purpose:             │
│  • DC01 (PDC)         │             │  • DC02               │             │  • DC03               │
│  • Management Hub     │             │  • WorkSpaces VDI     │             │  • Manila WorkSpaces  │
│                       │             │  • AD Connector       │             │  • AD Connector       │
└───────────────────────┘             └───────────────────────┘             └───────────────────────┘
            ▲                                         ▲                                         ▲
            │                                         │                                         │
            └─────────────────────────────────────────┴─────────────────────────────────────────┘
                                         TGW Peering (Full Mesh)
```

## 2.2 Regional Purpose

| Region | CIDR | Primary Purpose | Key Resources |
|---|---|---|---|
| us-east-2 | x.x.x.x/xx | Management Hub | DC01 (PDC), Secrets Manager, Terraform State |
| us-east-1 | x.x.x.x/xx | Primary VDI | DC02, WorkSpaces, AD Connector |
| ap-southeast-1 | x.x.x.x/xx | APAC VDI | DC03, Manila WorkSpaces, AD Connector |

---

# 3. VPC Architecture

## 3.1 IP Address Allocation

The infrastructure uses a Class A private address space (x.x.x.x/xx) subdivided by region:

```
x.x.x.x/xx (Master Allocation)
├── x.x.x.x/xx  → ap-southeast-1 (Singapore/Manila)
├── x.x.x.x/xx  → us-east-1 (N. Virginia)
└── x.x.x.x/xx  → us-east-2 (Ohio)
```

## 3.2 US-EAST-2 VPC (x.x.x.x/xx)

**VPC Name:** account-111122223333-vpc  
**VPC ID:** vpc-066b5d5ade267680f

| Subnet Tier | CIDR Blocks | Purpose |
|---|---|---|
| Public | x.x.x.x/xx, x.x.x.x/xx | NAT Gateway, Internet-facing |
| Private | x.x.x.x/xx, x.x.x.x/xx | General workloads |
| Inspection | x.x.x.x/xx, x.x.x.x/xx | Network Firewall endpoints |
| TGW Attachment | x.x.x.x/xx, x.x.x.x/xx | Transit Gateway attachment |
| Management | x.x.x.x/xx, x.x.x.x/xx, x.x.x.x/xx | Domain Controllers (DC01: x.x.x.x) |

## 3.3 US-EAST-1 VPC (x.x.x.x/xx)

**VPC Name:** org-use1-workspaces-vpc  
**VPC ID:** (managed via Terraform)

| Subnet Tier | CIDR Blocks | Purpose |
|---|---|---|
| Public | x.x.x.x/xx, x.x.x.x/xx | NAT Gateway, Internet-facing |
| Private | x.x.x.x/xx, x.x.x.x/xx | WorkSpaces VDI |
| Inspection | x.x.x.x/xx, x.x.x.x/xx | Network Firewall endpoints |
| TGW Attachment | x.x.x.x/xx, x.x.x.x/xx | Transit Gateway attachment |
| Management | x.x.x.x/xx, x.x.x.x/xx, x.x.x.x/xx | DC02 (x.x.x.x), AD Connector |

## 3.4 AP-SOUTHEAST-1 VPC (x.x.x.x/xx)

**VPC Name:** org-apse1-manila-vpc  
**VPC ID:** vpc-0c084be0ef4b0fe7f

| Subnet Tier | CIDR Blocks | Purpose |
|---|---|---|
| Public/Egress | x.x.x.x/xx, x.x.x.x/xx, x.x.x.x/xx | NAT Gateway |
| Private/Sandbox | x.x.x.x/xx, x.x.x.x/xx, x.x.x.x/xx | General workloads |
| Inspection | x.x.x.x/xx, x.x.x.x/xx, x.x.x.x/xx | Network Firewall endpoints |
| TGW Attachment | x.x.x.x/xx, x.x.x.x/xx, x.x.x.x/xx | Transit Gateway attachment |
| Management | x.x.x.x/xx, x.x.x.x/xx, x.x.x.x/xx | DC03 (x.x.x.x), AD Connector |
| VDI | x.x.x.x/xx, x.x.x.x/xx, x.x.x.x/xx | Manila WorkSpaces |

---

# 4. Subnet Tier Design

## 4.1 Subnet Tier Descriptions

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VPC ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐     ┌──────────────┐                                      │
│  │   PUBLIC     │     │  INSPECTION  │     ← Internet Gateway               │
│  │   SUBNETS    │     │   SUBNETS    │     ← NAT Gateway                    │
│  │              │     │              │     ← Network Firewall Endpoints     │
│  └──────┬───────┘     └──────┬───────┘                                      │
│         │                    │                                               │
│         │    ┌───────────────┤                                               │
│         │    │               │                                               │
│         ▼    ▼               ▼                                               │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                 │
│  │   PRIVATE    │     │  MANAGEMENT  │     │     VDI      │                 │
│  │   SUBNETS    │     │   SUBNETS    │     │   SUBNETS    │                 │
│  │              │     │              │     │              │                 │
│  │ • Workloads  │     │ • DCs        │     │ • WorkSpaces │                 │
│  │ • Apps       │     │ • AD Connect │     │ • Local Zone │                 │
│  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘                 │
│         │                    │                    │                          │
│         └────────────────────┼────────────────────┘                          │
│                              │                                               │
│                              ▼                                               │
│                    ┌──────────────┐                                          │
│                    │     TGW      │                                          │
│                    │  ATTACHMENT  │     ← Transit Gateway VPC Attachment    │
│                    │   SUBNETS    │     ← Appliance Mode Enabled            │
│                    └──────────────┘                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 4.2 Tier Purposes

| Tier | Purpose | Resources |
|---|---|---|
| **Public** | Internet ingress/egress, NAT Gateways | NAT Gateway, EIPs, ALBs (future) |
| **Inspection** | Network Firewall endpoint placement | AWS Network Firewall endpoints |
| **Private** | Internal workloads, WorkSpaces | EC2, WorkSpaces (us-east-1) |
| **Management** | Infrastructure services | Domain Controllers, AD Connector, SSM endpoints |
| **VDI** | Dedicated WorkSpaces (ap-southeast-1) | WorkSpaces in regional AZs |
| **TGW Attachment** | Transit Gateway attachment | TGW VPC attachments |

---

# 5. Transit Gateway Architecture

## 5.1 Transit Gateway Summary

| Region | TGW ID | ASN | Route Table ID |
|---|---|---|---|
| us-east-2 | tgw-0dcbbab20d066677a | 64512 | tgw-rtb-06df8087223b965ca |
| us-east-1 | tgw-019947c7ae3f31028 | 64513 | tgw-rtb-0ccab2c5a385c3cc7 |
| ap-southeast-1 | tgw-0877cd6c993b09f29 | 64512 | tgw-rtb-04e5cf4513071c7a6 |

## 5.2 Transit Gateway Peering (Full Mesh)

```
                        ┌─────────────────────────────────────┐
                        │           TGW PEERING MESH          │
                        └─────────────────────────────────────┘

           US-EAST-2                                         US-EAST-1
        ┌─────────────┐                                   ┌─────────────┐
        │    TGW      │◄─────────────────────────────────►│    TGW      │
        │  64512      │     tgw-attach-03826f462d7457af7  │  64513      │
        └──────┬──────┘         (use1 → use2)             └──────┬──────┘
               │                                                  │
               │                                                  │
               │  tgw-attach-0b92633becd02e182                   │  tgw-attach-0f37b07f88bf6c708
               │       (use2 → apse1)                            │       (use1 → apse1)
               │                                                  │
               │              AP-SOUTHEAST-1                      │
               │            ┌─────────────┐                       │
               └───────────►│    TGW      │◄──────────────────────┘
                            │  64512      │
                            └─────────────┘
```

## 5.3 Peering Attachments

| Source | Destination | Attachment ID | Role |
|---|---|---|---|
| us-east-1 | us-east-2 | tgw-attach-03826f462d7457af7 | use1 is requester |
| us-east-1 | ap-southeast-1 | tgw-attach-0f37b07f88bf6c708 | use1 is requester |
| us-east-2 | ap-southeast-1 | tgw-attach-0b92633becd02e182 | use2 is requester |

## 5.4 Transit Gateway Configuration

All Transit Gateways are configured with:

| Setting | Value | Rationale |
|---|---|---|
| DNS Support | Enabled | Route53 Resolver integration |
| VPN ECMP Support | Enabled | Future VPN scalability |
| Auto-Accept Shared Attachments | Enabled | Simplified cross-account connectivity |
| Default Route Table Association | Enabled | Automatic VPC route propagation |
| Default Route Table Propagation | Enabled | Automatic VPC route learning |
| **Appliance Mode** | **Enabled** | **Symmetric routing through Network Firewall** |

**Critical: Appliance Mode**  
Appliance mode is mandatory for Network Firewall integration. Without it, return traffic may not traverse the same firewall endpoint, causing asymmetric routing and dropped connections.

---

# 6. Network Firewall Architecture

## 6.1 Firewall Inventory

| Region | Firewall Name | VPC | Log Retention |
|---|---|---|---|
| us-east-2 | org-account-111122223333-firewall | vpc-066b5d5ade267680f | 90 days |
| us-east-1 | org-use1-firewall | org-use1-workspaces-vpc | 90 days |
| ap-southeast-1 | manila-landing-pad-firewall | vpc-0c084be0ef4b0fe7f | 365 days |

## 6.2 Firewall Policy Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FIREWALL POLICY STRUCTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    STATELESS PROCESSING                              │    │
│  │                                                                       │    │
│  │  Default Action: aws:forward_to_sfe (Forward to Stateful Engine)    │    │
│  │  Fragment Action: aws:forward_to_sfe                                 │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    STATEFUL PROCESSING                               │    │
│  │                    (STRICT_ORDER Mode)                               │    │
│  │                                                                       │    │
│  │  Default Action: aws:drop_strict (DROP ALL unmatched traffic)       │    │
│  │                                                                       │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │  Priority 50: MANAGEMENT BYPASS                              │    │    │
│  │  │  • Management subnet unrestricted outbound                   │    │    │
│  │  │  • Cross-region management traffic                           │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                              │                                       │    │
│  │                              ▼                                       │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │  Priority 100: DOMAIN ALLOWLIST                              │    │    │
│  │  │  • HTTP_HOST / TLS_SNI filtering                             │    │    │
│  │  │  • AWS services, Microsoft, CAs, etc.                        │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                              │                                       │    │
│  │                              ▼                                       │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │  Priority 200: INTER-SUBNET & WORKSPACES                     │    │    │
│  │  │  • VPC internal traffic                                      │    │    │
│  │  │  • AD protocols (local & cross-region)                       │    │    │
│  │  │  • WorkSpaces streaming (PCoIP/WSP)                          │    │    │
│  │  │  • DNS, NTP, HTTPS                                           │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                              │                                       │    │
│  │                              ▼                                       │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │  DEFAULT: DROP ALL (aws:drop_strict)                         │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                                                                       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 6.3 Rule Group Details

### 6.3.1 Management Bypass (Priority 50)

Allows unrestricted traffic for management subnets and cross-region management communication.

| SID | Protocol | Source | Destination | Action |
|---|---|---|---|---|
| 50001 | TCP | MGMT_SUBNETS | any | PASS |
| 50002 | UDP | MGMT_SUBNETS | any | PASS |
| 50003 | ICMP | MGMT_SUBNETS | any | PASS |
| 50010-50014 | TCP/UDP/ICMP | PEER_VPCS | MGMT_SUBNETS | PASS |

### 6.3.2 Domain Allowlist (Priority 100)

Controls outbound HTTP/HTTPS traffic via SNI/Host header inspection.

| Category | Domains |
|---|---|
| AWS Services | `.amazonaws.com`, `.amazon.com` |
| WorkSpaces | `.awsapps.com`, `.workspaces.aws`, `.workspaces.amazonaws.com`, `.skylight.local`, `.opfcaptive.com` |
| Microsoft/Azure AD | `.microsoft.com`, `.microsoftonline.com`, `.windows.net`, `.windowsupdate.com`, `.office.com`, `.office365.com`, `.outlook.com`, `.sharepoint.com` |
| Certificate Authorities | `.digicert.com`, `.verisign.com`, `.entrust.net` |
| Time Services | `.time.windows.com`, `.time.nist.gov` |
| Package Managers | `.ubuntu.com`, `.debian.org` |
| Development | `.github.com`, `.githubusercontent.com` |

### 6.3.3 Inter-Subnet & WorkSpaces (Priority 200)

Detailed protocol-level rules for internal and cross-region traffic.

**VPC Internal Traffic:**

| SID | Protocol | Port | Description |
|---|---|---|---|
| 100001 | TCP | any | VPC internal TCP (established) |
| 100002 | UDP | any | VPC internal UDP |
| 100003 | ICMP | any | VPC internal ICMP |

**DNS/NTP/Web:**

| SID | Protocol | Port | Description |
|---|---|---|---|
| 100010-100011 | TCP/UDP | 53 | DNS |
| 100012 | UDP | 123 | NTP |
| 100020-100021 | TCP | 443/80 | HTTPS/HTTP outbound |

**Active Directory Protocols (Local & Cross-Region):**

| SID | Protocol | Port | Description |
|---|---|---|---|
| 100100-100101 | TCP/UDP | 88 | Kerberos |
| 100110-100111 | TCP/UDP | 389 | LDAP |
| 100120 | TCP | 636 | LDAPS |
| 100130 | TCP | 3268-3269 | Global Catalog |
| 100140 | TCP | 445 | SMB |
| 100150 | TCP | 135 | RPC Endpoint Mapper |
| 100160 | TCP | 49152-65535 | RPC Dynamic Ports |
| 100170-100171 | TCP/UDP | 464 | Kerberos Password Change |

**WorkSpaces Streaming:**

| SID | Protocol | Port | Direction | Description |
|---|---|---|---|---|
| 100400-100401 | TCP/UDP | 4172 | Inbound | PCoIP |
| 100402-100403 | TCP/UDP | 4195 | Inbound | WSP |
| 100410-100413 | TCP/UDP | 4172/4195 | Outbound | PCoIP/WSP |

**Default Drop:**

| SID | Protocol | Action |
|---|---|---|
| 999998 | TCP | DROP |
| 999999 | UDP | DROP |

---

# 7. Traffic Flow Patterns

## 7.1 North-South Traffic (Internet Egress)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      NORTH-SOUTH TRAFFIC FLOW                                │
│                      (Private Subnet → Internet)                             │
└─────────────────────────────────────────────────────────────────────────────┘

    PRIVATE SUBNET                INSPECTION SUBNET              PUBLIC SUBNET
  ┌─────────────────┐           ┌─────────────────┐           ┌─────────────────┐
  │                 │           │                 │           │                 │
  │   WorkSpace     │──────────►│ Network Firewall│──────────►│   NAT Gateway   │──────► Internet
  │   (x.x.x.x)    │     ①     │   Endpoint      │     ②     │                 │    ③
  │                 │           │                 │           │                 │
  └─────────────────┘           └─────────────────┘           └─────────────────┘
         │                             │                             │
         │                             │                             │
         ▼                             ▼                             ▼
  ┌─────────────────┐           ┌─────────────────┐           ┌─────────────────┐
  │ Route Table:    │           │ Route Table:    │           │ Route Table:    │
  │ x.x.x.x/xx →     │           │ x.x.x.x/xx →     │           │ x.x.x.x/xx →     │
  │ vpce-fw-endpoint│           │ nat-gateway     │           │ igw             │
  └─────────────────┘           └─────────────────┘           └─────────────────┘

① Private subnet routes x.x.x.x/xx to Network Firewall endpoint
② Inspection subnet routes x.x.x.x/xx to NAT Gateway
③ Public subnet routes x.x.x.x/xx to Internet Gateway
```

**Return Traffic Path:**
```
Internet → IGW → NAT Gateway → Public RT (routes to FW for private CIDRs) → 
Network Firewall → Private Subnet
```

## 7.2 East-West Traffic (Cross-Region via TGW)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      EAST-WEST TRAFFIC FLOW                                  │
│                    (us-east-1 WorkSpace → us-east-2 DC01)                    │
└─────────────────────────────────────────────────────────────────────────────┘

US-EAST-1                                                              US-EAST-2
┌──────────────────────────────────────┐    ┌──────────────────────────────────────┐
│                                      │    │                                      │
│  ┌──────────┐      ┌──────────┐      │    │      ┌──────────┐      ┌──────────┐  │
│  │WorkSpace │─────►│ Network  │      │    │      │ Network  │◄─────│   DC01   │  │
│  │x.x.x.x  │  ①  │ Firewall │      │    │      │ Firewall │  ⑥  │x.x.x.x │  │
│  └──────────┘      └────┬─────┘      │    │      └────┬─────┘      └──────────┘  │
│                         │            │    │           │                          │
│                         │ ②          │    │        ⑤ │                          │
│                         ▼            │    │           ▼                          │
│                   ┌──────────┐       │    │     ┌──────────┐                     │
│                   │   TGW    │       │    │     │   TGW    │                     │
│                   │ Attach   │       │    │     │ Attach   │                     │
│                   └────┬─────┘       │    │     └────┬─────┘                     │
│                        │             │    │          │                           │
└────────────────────────┼─────────────┘    └──────────┼───────────────────────────┘
                         │                             │
                         │ ③        TGW PEERING     ④ │
                         ▼                             ▼
                   ┌──────────┐                 ┌──────────┐
                   │   TGW    │◄───────────────►│   TGW    │
                   │ use1     │                 │ use2     │
                   └──────────┘                 └──────────┘

① WorkSpace routes x.x.x.x/xx to Network Firewall endpoint
② Firewall passes (AD traffic rule), routes to TGW
③ TGW routes x.x.x.x/xx via peering attachment
④ Peering delivers to us-east-2 TGW
⑤ TGW attachment subnet routes x.x.x.x/xx to Network Firewall
⑥ Firewall passes (management bypass), delivers to DC01
```

## 7.3 Intra-VPC Traffic

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      INTRA-VPC TRAFFIC FLOW                                  │
│                    (Private Subnet → Management Subnet)                      │
└─────────────────────────────────────────────────────────────────────────────┘

All intra-VPC traffic between different subnet tiers traverses the Network 
Firewall to ensure consistent security policy enforcement.

  PRIVATE SUBNET                  INSPECTION SUBNET              MANAGEMENT SUBNET
  ┌─────────────────┐           ┌─────────────────┐           ┌─────────────────┐
  │                 │           │                 │           │                 │
  │   Application   │──────────►│ Network Firewall│──────────►│ Domain Controller│
  │   (x.x.x.x)    │           │   Endpoint      │           │   (x.x.x.x)   │
  │                 │           │                 │           │                 │
  └─────────────────┘           └─────────────────┘           └─────────────────┘

Firewall Rule Applied: SID 100100-100160 (AD Protocol Rules)
```

---

# 8. Routing Architecture

## 8.1 Route Table Summary

Each VPC contains multiple route tables for different subnet tiers:

| Route Table | Subnet Tier | Default Route (x.x.x.x/xx) | Cross-Region Routes |
|---|---|---|---|
| Public RT | Public | Internet Gateway | Via Firewall |
| Inspection RT | Inspection | NAT Gateway | Via TGW |
| TGW RT | TGW Attachment | Firewall Endpoint | N/A (TGW handles) |
| Private RT | Private | Firewall Endpoint | Via Firewall → TGW |
| Management RT | Management | Firewall Endpoint | Via Firewall → TGW |
| VDI RT | VDI | Firewall Endpoint | Via Firewall → TGW |

## 8.2 Routing Decision Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ROUTING DECISION TREE                                │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │  Source Packet  │
                              └────────┬────────┘
                                       │
                                       ▼
                          ┌────────────────────────┐
                          │ Destination in same    │
                          │ VPC (local CIDR)?      │
                          └────────────┬───────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │ YES              │                  │ NO
                    ▼                  │                  ▼
           ┌────────────────┐          │         ┌────────────────┐
           │ Same Subnet?   │          │         │ Peer VPC CIDR? │
           └───────┬────────┘          │         │ (5.x.0.0/16)   │
                   │                   │         └───────┬────────┘
        ┌──────────┼──────────┐        │                 │
        │ YES      │          │ NO     │      ┌──────────┼──────────┐
        ▼          │          ▼        │      │ YES      │          │ NO
   ┌─────────┐     │    ┌─────────┐    │      ▼          │          ▼
   │ Direct  │     │    │ Via     │    │ ┌─────────┐     │    ┌─────────┐
   │ (local) │     │    │Firewall │    │ │Via FW   │     │    │Via FW   │
   └─────────┘     │    │Endpoint │    │ │then TGW │     │    │then NAT │
                   │    └─────────┘    │ └─────────┘     │    │(internet)│
                   │                   │                 │    └─────────┘
                   └───────────────────┘                 │
                                                         │
                                                         ▼
                                              ┌─────────────────────┐
                                              │ All traffic through │
                                              │ Network Firewall    │
                                              │ for inspection      │
                                              └─────────────────────┘
```

## 8.3 Critical Route Entries

### 8.3.1 Private/Management Subnet Route Tables

| Destination | Target | Purpose |
|---|---|---|
| x.x.x.x/xx | vpce-{fw-endpoint} | Internet via Firewall |
| x.x.x.x/xx | vpce-{fw-endpoint} | Cross-region (us-east-1) |
| x.x.x.x/xx | vpce-{fw-endpoint} | Cross-region (us-east-2) |
| x.x.x.x/xx | vpce-{fw-endpoint} | Cross-region (ap-southeast-1) |

### 8.3.2 TGW Attachment Subnet Route Tables

| Destination | Target | Purpose |
|---|---|---|
| x.x.x.x/xx | vpce-{fw-endpoint} | Return traffic via Firewall |
| x.x.x.x/xx | vpce-{fw-endpoint} | Return to private subnets |
| x.x.x.x/xx | vpce-{fw-endpoint} | Return to management subnets |

### 8.3.3 Inspection Subnet Route Tables

| Destination | Target | Purpose |
|---|---|---|
| x.x.x.x/xx | nat-{id} | Internet egress |
| x.x.x.x/xx | tgw-{id} | Cross-region via TGW |
| x.x.x.x/xx | tgw-{id} | Cross-region via TGW |
| x.x.x.x/xx | tgw-{id} | Cross-region via TGW |

### 8.3.4 Public Subnet Route Table

| Destination | Target | Purpose |
|---|---|---|
| x.x.x.x/xx | igw-{id} | Internet |
| x.x.x.x/xx | vpce-{fw-endpoint} | Return traffic to private |
| x.x.x.x/xx | vpce-{fw-endpoint} | Return traffic to management |
| x.x.x.x/xx | vpce-{fw-endpoint} | Cross-region return |
| x.x.x.x/xx | vpce-{fw-endpoint} | Cross-region return |

---

# 9. Design Decisions

## 9.1 Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **IP Addressing** | x.x.x.x/xx Class A | Non-RFC1918 space avoids conflicts with corporate networks; large allocation for future growth |
| **Inter-Region Connectivity** | TGW Peering (Full Mesh) | Lower latency than VPN; scalable; supports transitive routing |
| **Security Model** | Drop-by-default Firewall | Zero Trust; explicit allow only; full traffic visibility |
| **NAT Strategy** | Single NAT per region | Cost optimization; acceptable for non-production |
| **Firewall Placement** | Dedicated inspection subnets | Symmetric routing; simplified route table management |
| **TGW Appliance Mode** | Enabled | Required for symmetric routing through Network Firewall |
| **Subnet Isolation** | Tier-based with separate route tables | Granular traffic control; defense in depth |

## 9.2 Security Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Management Bypass** | Unrestricted for DC subnets | Domain Controllers need broad protocol access; compensated by security groups |
| **Domain Filtering** | Allowlist only | Prevents data exfiltration; limits C2 channels |
| **AD Protocol Rules** | Explicit port allowance | Prevents lateral movement outside AD protocols |
| **WorkSpaces Streaming** | PCoIP (4172) + WSP (4195) | Both protocols supported for client compatibility |
| **Logging** | Alert + Flow logs to CloudWatch | Full visibility; 90-365 day retention for forensics |

## 9.3 Operational Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Terraform State** | S3 + DynamoDB in us-east-2 | Centralized state; state locking; cross-region access |
| **Module Design** | Shared modules per resource type | Code reuse; consistency across regions |
| **Tagging Strategy** | Provider default_tags + merge | Automatic compliance; reduced human error |
| **Log Retention** | 90 days (us-east-1/2), 365 days (ap-southeast-1) | Compliance requirements vary by region |

---

# 10. Failure Modes and Recovery

## 10.1 Single Points of Failure

| Component | Risk | Mitigation |
|---|---|---|
| Single NAT Gateway | Region-wide internet outage | Acceptable for account-111122223333; production should use multi-AZ NAT |
| Network Firewall | Single endpoint per AZ | AWS managed; endpoints are AZ-redundant |
| Transit Gateway | Regional TGW failure | Each TGW is regional; peer routes provide fallback |
| Domain Controller | AD authentication failure | Three DCs across three regions; automatic failover |

## 10.2 Recovery Procedures

| Scenario | Recovery |
|---|---|
| NAT Gateway failure | Terraform will recreate; ~5 minute outage |
| Network Firewall endpoint failure | AWS auto-heals; traffic shifts to healthy endpoints |
| TGW Peering failure | Traffic routes via alternate peer (e.g., use1→apse1 if use1→use2 fails) |
| Region failure | Workloads in other regions continue; DNS-based failover for AD |

---

# 11. Monitoring and Observability

## 11.1 CloudWatch Log Groups

| Log Group | Content | Retention |
|---|---|---|
| `/aws/networkfirewall/{name}/alerts` | Firewall rule matches, drops | 90-365 days |
| `/aws/networkfirewall/{name}/flow` | All traffic flows | 90-365 days |

## 11.2 Key Metrics to Monitor

| Metric | Threshold | Alert Action |
|---|---|---|
| Firewall dropped packets | > 1000/min | Investigate blocked traffic |
| TGW bytes transferred | Baseline + 50% | Cost alert |
| NAT Gateway ErrorPortAllocation | > 0 | Scale NAT or review source |
| VPC Flow Logs REJECT | > 100/min | Security review |

## 11.3 Useful CloudWatch Insights Queries

```sql
-- Top dropped destinations (Alert logs)
fields @timestamp, event.dest_ip, event.dest_port
| filter event.event_type = "alert" and event.alert.action = "blocked"
| stats count(*) as drops by event.dest_ip, event.dest_port
| sort drops desc
| limit 20

-- Cross-region traffic volume (Flow logs)
fields @timestamp, event.src_ip, event.dest_ip, event.bytes
| filter event.src_ip like /^5\.4\./ and event.dest_ip like /^5\.5\./
| stats sum(event.bytes) as total_bytes by bin(1h)
```

---

# 12. Future Considerations

## 12.1 Planned Enhancements

| Enhancement | Priority | Complexity |
|---|---|---|
| Multi-AZ NAT Gateways | Medium | Low |
| VPC Flow Logs | High | Low |
| AWS Firewall Manager | Medium | Medium |
| Centralized egress VPC | Low | High |
| AWS Network Firewall IPS rules | Medium | Medium |

## 12.2 Scalability Path

| Current | Future State | Trigger |
|---|---|---|
| 3 regions | Additional regions | APAC/EMEA expansion |
| Single NAT | Multi-AZ NAT | Production workloads |
| Per-region firewalls | Centralized inspection VPC | > 5 VPCs |
| Manual domain allowlist | AWS Managed Rule Groups | Compliance requirement |

---

# 13. Reference Information

## 13.1 Resource Identifiers

### VPCs

| Region | VPC ID | CIDR |
|---|---|---|
| us-east-2 | vpc-066b5d5ade267680f | x.x.x.x/xx |
| us-east-1 | (Terraform managed) | x.x.x.x/xx |
| ap-southeast-1 | vpc-0c084be0ef4b0fe7f | x.x.x.x/xx |

### Transit Gateways

| Region | TGW ID | Route Table ID | ASN |
|---|---|---|---|
| us-east-2 | tgw-0dcbbab20d066677a | tgw-rtb-06df8087223b965ca | 64512 |
| us-east-1 | tgw-019947c7ae3f31028 | tgw-rtb-0ccab2c5a385c3cc7 | 64513 |
| ap-southeast-1 | tgw-0877cd6c993b09f29 | tgw-rtb-04e5cf4513071c7a6 | 64512 |

### Network Firewalls

| Region | Name |
|---|---|
| us-east-2 | org-account-111122223333-firewall |
| us-east-1 | org-use1-firewall |
| ap-southeast-1 | manila-landing-pad-firewall |

### Domain Controllers

| Name | Region | IP | Instance ID |
|---|---|---|---|
| DC01 | us-east-2 | x.x.x.x | i-0d74f088f44fc088b |
| DC02 | us-east-1 | x.x.x.x | i-057c205efd2d28087 |
| DC03 | ap-southeast-1 | x.x.x.x | i-0f2607ac2de5b1f24 |

## 13.2 Terraform Repositories

| Repository | Purpose | State Key |
|---|---|---|
| org-aws-networking | VPCs, subnets, firewalls, TGWs | `networking/{region}/terraform.tfstate` |
| org-aws-ActiveDirectory | Domain Controllers, Route53, IAM | `account-111122223333/terraform.tfstate` |
| org-workspaces-vdi | WorkSpaces, AD Connectors | `workspaces/{region}/terraform.tfstate` |

## 13.3 State Backend

| Component | Value |
|---|---|
| S3 Bucket | org-terraform-state-account-111122223333-111122223333 |
| DynamoDB Table | org-terraform-state-account-111122223333 |
| Region | us-east-2 |

---

# 14. Document History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | December 16, 2025 | Platform Engineering | Initial release |

---

*This document should be reviewed and updated whenever network architecture changes are made.*
