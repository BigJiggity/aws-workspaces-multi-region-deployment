# WorkSpaces Platform Pilot - Project Overview and Documentation Index

## Overview
This project manages the WorkSpaces Platform Pilot infrastructure in AWS using Terraform and Terragrunt.

Primary scope:
- Shared Terraform backend (S3, DynamoDB, KMS)
- WorkSpaces personal tiers (Standard, SOC, Dev)
- WorkSpaces pools (Standard, SOC, Dev)
- Installs S3 bucket
- Deployment automation scripts and operational runbooks

Environment:
- AWS Account: `111122223333`
- Region: `us-east-1`
- Directory: `workspaces-platform.local` (`d-0000000000`)

## Documentation Index

### Repository-Level Docs
- [Root Project README](../README.md)
- [Prerequisites](../PREREQUISITES.md)
- [Style Guide](../STYLE_GUIDE.md)
- [AWS Well-Architected Checklist](../WELL_ARCHITECTED_CHECKLIST.md)

### Backend
- [Backend Runbook](../backend/README.md)

### WorkSpaces Personal Tiers
- [Standard Tier Runbook](../live/aws/aws-workspaces-platform/account-111122223333/us-east-1/standard/README.md)
- [SOC Tier Runbook](../live/aws/aws-workspaces-platform/account-111122223333/us-east-1/soc/README.md)
- [Dev Tier Runbook](../live/aws/aws-workspaces-platform/account-111122223333/us-east-1/dev/README.md)

### WorkSpaces Pools
- [Standard Pool Runbook](../live/aws/aws-workspaces-platform/account-111122223333/us-east-1/standard-pool/README.md)
- [SOC Pool Runbook](../live/aws/aws-workspaces-platform/account-111122223333/us-east-1/soc-pool/README.md)
- [Dev Pool Runbook](../live/aws/aws-workspaces-platform/account-111122223333/us-east-1/dev-pool/README.md)

### Installs Bucket
- [Installs Bucket Runbook](../live/aws/aws-workspaces-platform/account-111122223333/us-east-1/installs-bucket/README.md)

### Confluence-Formatted Pages
- [00 - Home](./confluence/00-Home.md)
- [01 - Architecture and Networking](./confluence/01-Architecture-and-Networking.md)
- [02 - Deployment Runbook](./confluence/02-Deployment-Runbook.md)
- [03 - Operations and Support](./confluence/03-Operations-and-Support.md)
- [04 - Configuration Inventory](./confluence/04-Configuration-Inventory.md)
- [05 - Standards and Well-Architected](./confluence/05-Standards-and-Well-Architected.md)

## Suggested Reading Order
1. Root Project README
2. Prerequisites
3. Backend Runbook
4. Personal Tier or Pool Runbook (as needed)
5. Operations and Support
6. Well-Architected Checklist

## Ownership and Updates
- Update this index whenever a new runbook, architecture page, or operational document is added.
- Keep bundle IDs, pool names, directory IDs, and network CIDRs synchronized with `common.hcl`.
