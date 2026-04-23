# Cloud Tagging Standards Document

| Document Information |  |
|---|---|
| Version | 2.0 |
| Last Updated | December 16, 2025 |
| Owner | System Architects |
| Classification | Internal |
| Scope | Multi-Cloud (AWS, Azure) |

---

# 1. Overview

This document defines the tagging standards for cloud resources across AWS and Azure environments. Consistent tagging enables cost allocation, resource organization, automation, security compliance, and cross-cloud governance.

## 1.1 Tagging Strategy

All resources are tagged using a layered approach:

1. **Provider/Subscription-Level Tags** - Applied automatically via IaC provider configuration
2. **Module/Resource Group-Level Tags** - Common tags inherited by child resources
3. **Resource-Specific Tags** - Additional tags for individual resources

## 1.2 Document Structure

| Section | Content |
|---|---|
| Sections 1-6 | Cloud-agnostic standards (apply to all platforms) |
| Section 7 | AWS-specific implementation |
| Section 8 | Azure-specific implementation |
| Section 9 | Cross-cloud governance |

---

# 2. Required Tags (All Clouds)

The following tags are **mandatory** on all resources across all cloud platforms:

| Tag Key | Description | Example Values |
|---|---|---|
| `Project` | Project or repository name | `org-aws-networking`, `org-azure-identity` |
| `Environment` | Deployment environment | `Production`, `account-111122223333`, `Development` |
| `ManagedBy` | Infrastructure management tool | `terraform`, `bicep`, `manual` |
| `Owner` | Team or individual responsible | `platform-team`, `john.smith@company.com` |
| `Name` | Human-readable resource name | `org-use1-workspaces-vpc` |

## 2.1 Tag Key Standards

| Rule | Standard |
|---|---|
| Case | PascalCase (e.g., `CostCenter`, `DataClass`) |
| Characters | Alphanumeric, hyphens allowed in values |
| Length | Key: max 128 chars, Value: max 256 chars |
| Reserved Prefixes | Avoid `aws:`, `azure:`, `microsoft:` |

---

# 3. Optional Tags (All Clouds)

The following tags are recommended based on resource type and organizational needs:

| Tag Key | Description | Example Values | Use Case |
|---|---|---|---|
| `Department` | Business department owner | `Engineering`, `IT`, `Finance` | Cost allocation |
| `CostCenter` | Cost center or billing code | `CC-12345`, `VDI-Infrastructure` | FinOps |
| `DataClass` | Data classification level | `Internal`, `Confidential`, `Public` | Security/Compliance |
| `Criticality` | Business criticality | `High`, `Medium`, `Low` | Incident response |
| `Region` | Cloud region identifier | `us-east-1`, `eastus`, `southeastasia` | Multi-region |
| `Application` | Application or service name | `workspaces-vdi`, `active-directory` | Application mapping |
| `Compliance` | Compliance framework | `SOC2`, `HIPAA`, `PCI-DSS` | Audit |
| `ExpirationDate` | Resource expiration | `2025-12-31` | Lifecycle management |

---

# 4. Naming Conventions (All Clouds)

## 4.1 Regional Name Prefix Format

Resources use a standardized name prefix based on cloud and region:

| Cloud | Region | Name Prefix |
|---|---|---|
| AWS | us-east-1 | `org-use1` |
| AWS | us-east-2 | `org-use2` |
| AWS | ap-southeast-1 | `org-apse1` |
| Azure | East US | `org-eus` |
| Azure | East US 2 | `org-eus2` |
| Azure | Southeast Asia | `org-sea` |

## 4.2 Resource Name Patterns

| Resource Type | AWS Pattern | Azure Pattern |
|---|---|---|
| Virtual Network | `{prefix}-{purpose}-vpc` | `{prefix}-{purpose}-vnet` |
| Subnet | `{prefix}-{tier}-{az}` | `{prefix}-{tier}-snet` |
| Security Group | `{prefix}-{service}-sg` | `{prefix}-{service}-nsg` |
| Virtual Machine | `org-{function}` | `org-{function}-vm` |
| Storage | `org-{purpose}-{account}` | `org{purpose}st` |
| Key Vault/Secrets | `org-{project}/{secret}` | `org-{project}-kv` |

---

# 5. Tag Inheritance Strategy

## 5.1 Inheritance Model

```
┌─────────────────────────────────────┐
│     Provider/Subscription Tags      │  ← Applied to all resources
│  (Project, Environment, ManagedBy)  │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│    Resource Group / Module Tags     │  ← Inherited by child resources
│    (Application, CostCenter, VPC)   │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│      Resource-Specific Tags         │  ← Individual resource context
│      (Name, Role, Site, Domain)     │
└─────────────────────────────────────┘
```

## 5.2 Tag Merging Priority

When tags conflict, the following priority applies (highest to lowest):

1. Resource-specific tags
2. Module/Resource Group tags
3. Provider/Subscription default tags

---

# 6. Tag Lexicon Reference (All Clouds)

## 6.1 Environment Values

| Value | Description |
|---|---|
| `Production` | Production workloads |
| `Staging` | Pre-production testing |
| `Development` | Active development |
| `account-111122223333` | Sandbox/experimental |

## 6.2 Project Values

| Value | Description |
|---|---|
| `org-aws-networking` | AWS VPC, subnets, firewalls, transit gateways |
| `account-111122223333` | AWS Active Directory domain controllers |
| `org-workspaces-vdi` | AWS WorkSpaces VDI infrastructure |
| `org-azure-identity` | Azure AD/Entra ID integration |
| `org-azure-networking` | Azure VNets, NSGs, peering |

## 6.3 Criticality Values

| Value | Description | SLA Impact |
|---|---|---|
| `Critical` | Business-critical, zero tolerance | 99.99% uptime |
| `High` | Important, immediate attention | 99.9% uptime |
| `Medium` | Standard priority | 99.5% uptime |
| `Low` | Best effort | No SLA |

## 6.4 DataClass Values

| Value | Description | Handling |
|---|---|---|
| `Public` | Publicly accessible | No restrictions |
| `Internal` | Internal use only | Authentication required |
| `Confidential` | Restricted access | Encryption + RBAC |
| `Restricted` | Highly sensitive | Encryption + MFA + Audit |

## 6.5 Role Values (Compute Resources)

| Value | Description |
|---|---|
| `PrimaryDC` | Primary Domain Controller |
| `SecondaryDC` | Secondary Domain Controller |
| `ReplicaDC` | Replica Domain Controller |
| `WebServer` | Web application server |
| `AppServer` | Application server |
| `DatabaseServer` | Database server |
| `JumpBox` | Bastion/jump host |

## 6.6 Site/Location Values

| Value | Cloud | Region |
|---|---|---|
| `US-East-1` | AWS | N. Virginia |
| `US-East-2` | AWS | Ohio |
| `AP-Southeast-1` | AWS | Singapore |
| `East-US` | Azure | Virginia |
| `East-US-2` | Azure | Virginia |
| `Southeast-Asia` | Azure | Singapore |

---

# 7. AWS-Specific Implementation

## 7.1 Provider Default Tags (Terraform)

```hcl
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}
```

## 7.2 AWS Variables Definition

```hcl
variable "environment" {
  description = "Environment name for tagging"
  type        = string
  validation {
    condition     = contains(["Production", "Staging", "Development", "account-111122223333"], var.environment)
    error_message = "Environment must be Production, Staging, Development, or account-111122223333."
  }
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "owner" {
  description = "Resource owner for tagging"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

## 7.3 AWS Common Tags Pattern

```hcl
locals {
  common_tags = merge(var.tags, {
    VPC    = var.vpc_name
    Region = var.region
  })
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = merge(local.common_tags, {
    Name = var.vpc_name
  })
}
```

## 7.4 AWS EC2 Instance Tagging

```hcl
resource "aws_instance" "dc01" {
  ami           = data.aws_ami.windows_2022.id
  instance_type = var.instance_type

  tags = merge(local.common_tags, {
    Name        = "org-dc01"
    Role        = "PrimaryDC"
    Domain      = var.ad_domain_name
    Site        = "US-East-2"
    Criticality = "Critical"
    DataClass   = "Confidential"
  })

  volume_tags = merge(local.common_tags, {
    Name = "org-dc01-root"
  })
}
```

## 7.5 AWS tfvars Example

```hcl
# Required Tags
region      = "us-east-1"
environment = "Production"
project     = "org-aws-networking"
name_prefix = "org-use1"
owner       = "platform-team"

# Optional Tags
tags = {
  Department  = "Engineering"
  CostCenter  = "VDI-Infrastructure"
  DataClass   = "Internal"
  Criticality = "High"
}
```

## 7.6 AWS Cost Allocation Tags

Activate these tags in AWS Billing Console → Cost Allocation Tags:

| Tag Key | Purpose |
|---|---|
| `Project` | Track costs by project |
| `Environment` | Track costs by environment |
| `Department` | Track costs by business unit |
| `CostCenter` | Track costs by cost center |
| `Owner` | Track costs by owner |

## 7.7 AWS Resource-Specific Tags

| AWS Resource | Additional Tags |
|---|---|
| EC2 Instance | `Role`, `Site`, `Domain` |
| VPC | `VPC` (name reference) |
| Subnet | `Tier` (public/private/management) |
| Security Group | `Service` |
| S3 Bucket | `DataClass`, `Retention` |
| RDS | `Engine`, `Criticality` |
| Lambda | `Application`, `Runtime` |

---

# 8. Azure-Specific Implementation

## 8.1 Provider Default Tags (Terraform)

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id

  # Note: Azure doesn't support provider-level default tags
  # Use resource group tags for inheritance
}
```

## 8.2 Azure Resource Group Tags (Terraform)

```hcl
resource "azurerm_resource_group" "this" {
  name     = "${var.name_prefix}-${var.project}-rg"
  location = var.location

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}
```

## 8.3 Azure Variables Definition

```hcl
variable "environment" {
  description = "Environment name for tagging"
  type        = string
  validation {
    condition     = contains(["Production", "Staging", "Development", "account-111122223333"], var.environment)
    error_message = "Environment must be Production, Staging, Development, or account-111122223333."
  }
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "owner" {
  description = "Resource owner for tagging"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

## 8.4 Azure Common Tags Pattern

```hcl
locals {
  common_tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    Location    = var.location
  })
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.name_prefix}-${var.purpose}-vnet"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = [var.vnet_cidr]

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-${var.purpose}-vnet"
  })
}
```

## 8.5 Azure Virtual Machine Tagging

```hcl
resource "azurerm_windows_virtual_machine" "dc01" {
  name                = "org-dc01-vm"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = "Standard_D2s_v3"

  tags = merge(local.common_tags, {
    Name        = "org-dc01-vm"
    Role        = "PrimaryDC"
    Domain      = var.ad_domain_name
    Site        = "East-US"
    Criticality = "Critical"
    DataClass   = "Confidential"
  })
}
```

## 8.6 Azure tfvars Example

```hcl
# Required Tags
location    = "eastus"
environment = "Production"
project     = "org-azure-identity"
name_prefix = "org-eus"
owner       = "platform-team"
cost_center = "CC-12345"

# Optional Tags
tags = {
  Department  = "Engineering"
  DataClass   = "Internal"
  Criticality = "High"
  Application = "active-directory"
}
```

## 8.7 Azure Policy for Tag Enforcement

```json
{
  "mode": "Indexed",
  "policyRule": {
    "if": {
      "anyOf": [
        {
          "field": "[concat('tags[', parameters('tagName'), ']')]",
          "exists": "false"
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  },
  "parameters": {
    "tagName": {
      "type": "String",
      "metadata": {
        "displayName": "Tag Name",
        "description": "Name of the tag to require"
      }
    }
  }
}
```

## 8.8 Azure Bicep Tagging Pattern

```bicep
param location string = resourceGroup().location
param environment string
param project string
param owner string

var commonTags = {
  Project: project
  Environment: environment
  ManagedBy: 'bicep'
  Owner: owner
  Location: location
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'org-eus-main-vnet'
  location: location
  tags: union(commonTags, {
    Name: 'org-eus-main-vnet'
  })
  properties: {
    addressSpace: {
      addressPrefixes: ['x.x.x.x/xx']
    }
  }
}
```

## 8.9 Azure Resource-Specific Tags

| Azure Resource | Additional Tags |
|---|---|
| Virtual Machine | `Role`, `Site`, `Domain` |
| Virtual Network | `VNet` (name reference) |
| Subnet | `Tier` (public/private/management) |
| NSG | `Service` |
| Storage Account | `DataClass`, `Retention`, `Replication` |
| SQL Database | `Engine`, `Criticality` |
| Function App | `Application`, `Runtime` |
| Key Vault | `DataClass`, `Compliance` |

---

# 9. Cross-Cloud Governance

## 9.1 Tag Mapping (AWS ↔ Azure)

| Purpose | AWS Tag | Azure Tag |
|---|---|---|
| Project identifier | `Project` | `Project` |
| Environment | `Environment` | `Environment` |
| IaC tool | `ManagedBy` | `ManagedBy` |
| Ownership | `Owner` | `Owner` |
| Resource name | `Name` | `Name` |
| Cost tracking | `CostCenter` | `CostCenter` |
| Data classification | `DataClass` | `DataClass` |
| Business criticality | `Criticality` | `Criticality` |
| Region/Location | `Region` | `Location` |

## 9.2 Cross-Cloud Reporting

Use consistent tag keys to enable unified reporting:

```sql
-- Example: Cross-cloud cost query (pseudo-SQL)
SELECT 
  cloud_provider,
  tags['Project'] as project,
  tags['Environment'] as environment,
  tags['CostCenter'] as cost_center,
  SUM(cost) as total_cost
FROM cloud_costs
WHERE date >= '2025-01-01'
GROUP BY cloud_provider, project, environment, cost_center
ORDER BY total_cost DESC
```

## 9.3 Governance Checklist

| Requirement | AWS Implementation | Azure Implementation |
|---|---|---|
| Required tags | AWS Config Rules | Azure Policy |
| Tag inheritance | Provider default_tags | Resource Group tags |
| Cost allocation | Cost Allocation Tags | Cost Management + Tags |
| Compliance | AWS Organizations Tag Policies | Azure Policy + Blueprints |
| Automation | AWS Tag Editor | Azure Resource Graph |

---

# 10. Tag Audit Checklist

Use this checklist when reviewing infrastructure (applies to all clouds):

## 10.1 Required Tags

- [ ] All resources have `Name` tag
- [ ] All resources have `Project` tag
- [ ] All resources have `Environment` tag
- [ ] All resources have `ManagedBy` tag
- [ ] All resources have `Owner` tag

## 10.2 Optional Tags (Based on Resource Type)

- [ ] Compute resources have `Role` tag
- [ ] Multi-region resources have `Region`/`Location` tag
- [ ] AD-related resources have `Domain` tag
- [ ] High-value resources have `Criticality` tag
- [ ] Data storage resources have `DataClass` tag
- [ ] Billable resources have `CostCenter` tag

## 10.3 Naming Standards

- [ ] Name prefixes follow cloud/regional convention
- [ ] Resource names are descriptive and consistent
- [ ] No special characters except hyphens
- [ ] Names are within length limits

---

# 11. Implementation Roadmap

## 11.1 Phase 1: Foundation (Week 1-2)

- [ ] Define required tag keys
- [ ] Create IaC templates with default tags
- [ ] Update existing Terraform/Bicep modules

## 11.2 Phase 2: Enforcement (Week 3-4)

- [ ] Implement AWS Config Rules
- [ ] Implement Azure Policies
- [ ] Enable cost allocation tags

## 11.3 Phase 3: Automation (Week 5-6)

- [ ] Create tag remediation scripts
- [ ] Set up compliance dashboards
- [ ] Configure alerting for non-compliant resources

## 11.4 Phase 4: Governance (Ongoing)

- [ ] Monthly tag compliance reviews
- [ ] Quarterly tag lexicon updates
- [ ] Annual tagging strategy review

---

# 12. Document History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | December 16, 2025 | System Architects | Initial release (AWS-only) |
| 2.0 | December 16, 2025 | System Architects | Cloud-agnostic rewrite with AWS and Azure sections |

---

*This document should be reviewed and updated whenever new tag keys are introduced, cloud platforms are added, or naming conventions change.*
