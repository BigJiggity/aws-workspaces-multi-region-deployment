# WorkSpaces Platform Pilot - Confluence Home

## Page Purpose
This page is the landing page for the WorkSpaces Platform Pilot implementation in AWS.

## Project Summary
- Project: WorkSpaces Platform Pilot
- AWS Account: `111122223333`
- Region: `us-east-1`
- Directory: `workspaces-platform.local` (`d-0000000000`)
- Infrastructure as Code: Terraform + Terragrunt
- State Backend: S3 + DynamoDB + KMS

## Documentation Tree
Create child pages in this order:
1. `01-Architecture-and-Networking`
2. `02-Deployment-Runbook`
3. `03-Operations-and-Support`
4. `04-Configuration-Inventory`
5. `05-Standards-and-Well-Architected`

## Scope
This documentation covers:
- Remote backend for shared Terraform/Terragrunt state
- WorkSpaces personal tiers (Standard/SOC/Dev)
- WorkSpaces pools (Standard/SOC/Dev)
- Installs S3 bucket
- Deployment scripts and operational workflows

## High-Level Architecture
{code:language=mermaid}
flowchart TD
  A["Terraform Backend<br/>(S3 + DynamoDB + KMS)"] --> B["Terragrunt Live Units"]
  B --> C["WorkSpaces Personal Tiers<br/>(standard / soc / dev)"]
  B --> D["WorkSpaces Pools<br/>(standard-pool / soc-pool / dev-pool)"]
  B --> E["Installs S3 Bucket"]

  C --> C1["Directory: workspaces-platform.local<br/>ID: d-0000000000"]
  D --> D1["Directory: workspaces-platform.local<br/>ID: d-0000000000"]
{code}

## Quick Links (Repository Mapping)
- Documentation index: `docs/README.md`
- Root project overview: `README.md`
- Backend runbook: `backend/README.md`
- Standard tier runbook: `live/.../standard/README.md`
- SOC tier runbook: `live/.../soc/README.md`
- Dev tier runbook: `live/.../dev/README.md`
- Standard pool runbook: `live/.../standard-pool/README.md`
- SOC pool runbook: `live/.../soc-pool/README.md`
- Dev pool runbook: `live/.../dev-pool/README.md`
- Prerequisites: `PREREQUISITES.md`
- Style guide: `STYLE_GUIDE.md`
- Well-Architected checklist: `WELL_ARCHITECTED_CHECKLIST.md`

## Change Management
- All IaC changes go through PR review before apply in shared environments.
- State locking is enabled via DynamoDB table.
- Sensitive values are stored in AWS Secrets Manager and not committed in source.
