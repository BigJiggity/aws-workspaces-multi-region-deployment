# Generic AWS Networking - account-111122223333 Account

Consolidated multi-region networking infrastructure for AWS account xxxxxxxxxxxx.

**Last Updated:** December 16, 2025

## Architecture Overview

```
                              ┌─────────────────────────────────────┐
                              │           US-EAST-1                 │
                              │         x.x.x.x/xx                  │
                              │                                     │
                              │  ┌───────────────────────────────┐  │
                              │  │  DC02 (x.x.x.x)             │  │
                              │  │  WorkSpaces VDI (testuser)    │  │
                              │  │  AD Connector → DC02/DC01     │  │
                              │  │  Network Firewall             │  │
                              │  │  Transit Gateway (ASN 64513)  │  │
                              │  └───────────────────────────────┘  │
                              └──────────────┬──────────────────────┘
                                             │
               ┌─────────────────────────────┼─────────────────────────────┐
               │   tgw-attach-xxxxxxxxxxxxxxxxx       tgw-attach-xxxxxxxxxxxxxxxxx
               │        TGW Peering          │        TGW Peering          │
               ▼                             │                             ▼
┌──────────────────────────────┐             │             ┌──────────────────────────────┐
│        US-EAST-2             │             │             │      AP-SOUTHEAST-1          │
│       x.x.x.x/xx             │             │             │       x.x.x.x/xx             │
│                              │             │             │                              │
│  ┌────────────────────────┐  │             │             │  ┌────────────────────────┐  │
│  │  DC01 (PDC) x.x.x.x  │  │◄────────────┴────────────►│  │  DC03       x.x.x.x  │  │
│  │  Network Firewall      │  │   tgw-attach-xxxxxxxxxxxxxxxxx   │  WorkSpaces (rochellec) │  │
│  │  Transit Gateway       │  │        TGW Peering        │  │  Network Firewall      │  │
│  │  (ASN 64512)           │  │                           │  │  Transit Gateway       │  │
│  └────────────────────────┘  │                           │  │  (ASN 64512)           │  │
└──────────────────────────────┘                           └──────────────────────────────┘
```

## Network Summary

| Region | VPC CIDR | Purpose | TGW ASN | Firewall Name |
|--------|----------|---------|---------|---------------|
| us-east-1 | x.x.x.x/xx | DC02, WorkSpaces VDI (US) | 64513 | org-use1-firewall |
| us-east-2 | x.x.x.x/xx | DC01 (PDC), Forest Root | 64512 | org-account-111122223333-firewall |
| ap-southeast-1 | x.x.x.x/xx | DC03, Manila WorkSpaces | 64512 | manila-landing-pad-firewall |

## Domain Controllers

| DC | IP Address | Region | Site | Instance ID |
|----|------------|--------|------|-------------|
| DC01 (PDC) | x.x.x.x | us-east-2a | US-East-2 | i-xxxxxxxxxxxxxxxxx |
| DC02 | x.x.x.x | us-east-1a | US-East-1 | i-xxxxxxxxxxxxxxxxx |
| DC03 | x.x.x.x | ap-southeast-1a | AP-Southeast-1 | i-xxxxxxxxxxxxxxxxx |

## TGW Peering Topology (Full Mesh)

| Source | Destination | Attachment ID | Status |
|--------|-------------|---------------|--------|
| us-east-1 | us-east-2 | tgw-attach-xxxxxxxxxxxxxxxxx | ✅ Active |
| us-east-1 | ap-southeast-1 | tgw-attach-xxxxxxxxxxxxxxxxx | ✅ Active |
| us-east-2 | ap-southeast-1 | tgw-attach-xxxxxxxxxxxxxxxxx | ✅ Active |

## Directory Structure

```
account-111122223333-account-xxxxxxxxxxxx/
├── README.md
├── modules/                    # Shared Terraform modules
│   ├── vpc/                    # VPC + IGW
│   ├── subnets/                # All subnet tiers + NAT GW + route tables
│   ├── network-firewall/       # AWS Network Firewall + rule groups
│   ├── transit-gateway/        # TGW + VPC attachment
│   └── tgw-peering/            # Cross-region TGW peering
├── us-east-1/                  # US-East-1 deployment
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   └── outputs.tf
├── us-east-2/                  # US-East-2 deployment
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   └── outputs.tf
└── ap-southeast-1/             # AP-Southeast-1 deployment
    ├── main.tf
    ├── variables.tf
    ├── terraform.tfvars
    └── outputs.tf
```

## Subnet Layout

### US-East-1 (x.x.x.x/xx)

| Tier | CIDR | AZ | Purpose |
|------|------|----|---------|
| Public | x.x.x.x/xx | us-east-1a | NAT Gateway |
| Public | x.x.x.x/xx | us-east-1b | NAT Gateway |
| Private | x.x.x.x/xx | us-east-1a | WorkSpaces |
| Private | x.x.x.x/xx | us-east-1b | WorkSpaces |
| Management | x.x.x.x/xx | us-east-1a | **DC02 (x.x.x.x)** |
| Management | x.x.x.x/xx | us-east-1b | AD Connector (WorkSpaces-supported AZ) |
| Management | x.x.x.x/xx | us-east-1c | AD Connector (WorkSpaces-supported AZ) |
| Inspection | x.x.x.x/xx | us-east-1a | Network Firewall |
| Inspection | x.x.x.x/xx | us-east-1b | Network Firewall |
| TGW | x.x.x.x/xx | us-east-1a | Transit Gateway |
| TGW | x.x.x.x/xx | us-east-1b | Transit Gateway |

> **Note:** WorkSpaces in us-east-1 requires subnets in specific AZs (use1-az2, use1-az4, use1-az6). 
> Management subnets in us-east-1b (use1-az2) and us-east-1c (use1-az4) are used for AD Connector and WorkSpaces Directory.

### US-East-2 (x.x.x.x/xx)

| Tier | CIDR | AZ | Purpose |
|------|------|----|---------|
| Public | x.x.x.x/xx | us-east-2a | NAT Gateway |
| Public | x.x.x.x/xx | us-east-2b | NAT Gateway |
| Private | x.x.x.x/xx | us-east-2a | Workloads |
| Private | x.x.x.x/xx | us-east-2b | Workloads |
| Management | x.x.x.x/xx | us-east-2a | **DC01 (x.x.x.x)** |
| Management | x.x.x.x/xx | us-east-2b | Reserved |
| Inspection | x.x.x.x/xx | us-east-2a | Network Firewall |
| Inspection | x.x.x.x/xx | us-east-2b | Network Firewall |
| TGW | x.x.x.x/xx | us-east-2a | Transit Gateway |
| TGW | x.x.x.x/xx | us-east-2b | Transit Gateway |

### AP-Southeast-1 (x.x.x.x/xx)

| Tier | CIDR | AZ | Purpose |
|------|------|----|---------|
| Public/Egress | x.x.x.x/xx | ap-southeast-1a | NAT Gateway |
| Public/Egress | x.x.x.x/xx | ap-southeast-1b | NAT Gateway |
| Public/Egress | x.x.x.x/xx | ap-southeast-1c | NAT Gateway |
| Private/Sandbox | x.x.x.x/xx | ap-southeast-1a | Sandbox |
| Private/Sandbox | x.x.x.x/xx | ap-southeast-1b | Sandbox |
| Private/Sandbox | x.x.x.x/xx | ap-southeast-1c | Sandbox |
| Management | x.x.x.x/xx | ap-southeast-1a | **DC03 (x.x.x.x)**, AD Connector |
| Management | x.x.x.x/xx | ap-southeast-1b | AD Connector |
| Management | x.x.x.x/xx | ap-southeast-1c | Reserved |
| VDI | x.x.x.x/xx | ap-southeast-1a | Manila WorkSpaces |
| VDI | x.x.x.x/xx | ap-southeast-1b | Manila WorkSpaces |
| VDI | x.x.x.x/xx | ap-southeast-1c | Manila WorkSpaces |
| Inspection | x.x.x.x/xx | ap-southeast-1a | Network Firewall |
| Inspection | x.x.x.x/xx | ap-southeast-1b | Network Firewall |
| Inspection | x.x.x.x/xx | ap-southeast-1c | Network Firewall |
| TGW | x.x.x.x/xx | ap-southeast-1a | Transit Gateway |
| TGW | x.x.x.x/xx | ap-southeast-1b | Transit Gateway |
| TGW | x.x.x.x/xx | ap-southeast-1c | Transit Gateway |

## Key Resources

### Transit Gateways

| Region | TGW ID | ASN | Route Table ID |
|--------|--------|-----|----------------|
| us-east-1 | tgw-xxxxxxxxxxxxxxxxx | 64513 | tgw-rtb-xxxxxxxxxxxxxxxxx |
| us-east-2 | tgw-xxxxxxxxxxxxxxxxx | 64512 | tgw-rtb-xxxxxxxxxxxxxxxxx |
| ap-southeast-1 | tgw-xxxxxxxxxxxxxxxxx | 64512 | tgw-rtb-xxxxxxxxxxxxxxxxx |

### Network Firewalls

| Region | Firewall | VPC |
|--------|----------|-----|
| us-east-1 | org-use1-firewall | org-use1-workspaces-vpc |
| us-east-2 | org-account-111122223333-firewall | vpc-xxxxxxxxxxxxxxxxx |
| ap-southeast-1 | manila-landing-pad-firewall | vpc-xxxxxxxxxxxxxxxxx |

## Traffic Flow Architecture

All cross-region traffic flows through Network Firewall for inspection:

```
Source Subnet → Firewall → Inspection Subnet → TGW → [Cross-Region] → TGW → Inspection Subnet → Firewall → Destination Subnet
```

### Key Routing Design

1. **Internal subnets** (private, management, VDI) route x.x.x.x/xx → Firewall
2. **TGW subnets** have explicit routes for internal subnet CIDRs → Firewall (prevents asymmetric routing)
3. **Inspection subnets** route peer VPC CIDRs → TGW
4. **TGW route tables** have routes to all three VPC CIDRs

## Firewall Rules Summary

All regions use consistent firewall rules with drop-by-default policy:

### Rule Groups (Priority Order)

1. **mgmt-bypass** (Priority 50): Management subnet unrestricted + peer VPC access
2. **domain-allow** (Priority 100): HTTPS domain allowlist
3. **inter-subnet** (Priority 200): VPC internal, AD protocols, WorkSpaces streaming

### Allowed Traffic

- **Management bypass**: Unrestricted outbound from management subnets
- **Cross-region management**: Full TCP/UDP/ICMP between management and peer VPCs
- **Domain allowlist**: AWS, Microsoft, WorkSpaces, certificate authorities
- **AD protocols**: Kerberos (88), LDAP (389/636), GC (3268-3269), SMB (445), RPC (135, 49152-65535)
- **WorkSpaces streaming**: PCoIP (4172), WSP (4195)
- **Drop-by-default**: All unmatched traffic logged and dropped

## Deployment

### Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- S3 bucket: `org-terraform-state-account-111122223333-xxxxxxxxxxxx`
- DynamoDB table: `org-terraform-state-account-111122223333`

### Deployment Order

```bash
# 1. Deploy US-East-2 first (has DC01)
cd account-111122223333-account-xxxxxxxxxxxx/us-east-2
terraform init && terraform apply

# 2. Deploy AP-Southeast-1
cd ../ap-southeast-1
terraform init && terraform apply

# 3. Deploy US-East-1 (has DC02)
cd ../us-east-1
terraform init && terraform apply
```

## Remote State References

Other projects can reference this infrastructure:

```hcl
# Reference US-East-1 networking
data "terraform_remote_state" "use1_networking" {
  backend = "s3"
  config = {
    bucket = "org-terraform-state-account-111122223333-xxxxxxxxxxxx"
    key    = "networking/us-east-1/terraform.tfstate"
    region = "us-east-2"
  }
}

# Use outputs
locals {
  use1_vpc_id          = data.terraform_remote_state.use1_networking.outputs.vpc_id
  use1_tgw_id          = data.terraform_remote_state.use1_networking.outputs.transit_gateway_id
  use1_mgmt_subnet_ids = data.terraform_remote_state.use1_networking.outputs.management_subnet_ids
}
```

## State Locations

| Region | Bucket | Key |
|--------|--------|-----|
| us-east-1 | org-terraform-state-account-111122223333-xxxxxxxxxxxx | networking/us-east-1/terraform.tfstate |
| us-east-2 | org-terraform-state-account-111122223333-xxxxxxxxxxxx | networking/us-east-2/terraform.tfstate |
| ap-southeast-1 | org-terraform-state-account-111122223333-xxxxxxxxxxxx | networking/ap-southeast-1/terraform.tfstate |

## Related Projects

| Project | Path | Purpose |
|---------|------|---------|
| org-aws-ActiveDirectory | org-aws-ActiveDirectory/account-111122223333-account-xxxxxxxxxxxx | Domain Controllers (DC01, DC02, DC03) |
| org-workspaces-vdi | org-workspaces-vdi/account-111122223333-account-xxxxxxxxxxxx | WorkSpaces (us-east-1, ap-southeast-1) |

## Changelog

### 2025-12-16

- Added third management subnet in us-east-1c (x.x.x.x/xx) for WorkSpaces AZ requirements
- DC02 migrated to us-east-1 (was us-east-2)
- Updated documentation with current instance IDs

### 2025-12-12

- AD domain example.internal rebuilt after catastrophic Terraform cascade
- New instance IDs for all three domain controllers

### 2025-12-10

- Rebuilt us-east-1 with correct CIDR (x.x.x.x/xx)
- Established full mesh TGW peering between all three regions
- Fixed asymmetric routing by adding TGW→Firewall routes for internal subnets
