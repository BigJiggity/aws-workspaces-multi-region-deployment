# Generic WorkSpaces VDI Infrastructure

Multi-region AWS WorkSpaces deployment with self-managed Active Directory.

**Last Updated:** December 16, 2025

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        US-EAST-2 (Ohio) – PRIMARY DC                        │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │         VPC x.x.x.x/xx (account-111122223333-vpc)                       │  │
│  │                                                                         │  │
│  │  ┌──────────────────────┐                                              │  │
│  │  │  DC01 (PDC)          │                                              │  │
│  │  │  x.x.x.x           │                                              │  │
│  │  │  i-xxxxxxxxxxxxxxxxx │                                              │  │
│  │  └──────────────────────┘                                              │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
           │                                              │
           │ TGW Peering (AD Replication)                 │ TGW Peering
           │                                              │
           ▼                                              ▼
┌───────────────────────────────────────┐  ┌───────────────────────────────────────┐
│     US-EAST-1 (N. Virginia)           │  │     AP-SOUTHEAST-1 (Singapore)        │
│     VPC x.x.x.x/xx                    │  │     VPC x.x.x.x/xx                    │
│  ┌─────────────────────────────────┐  │  │  ┌─────────────────────────────────┐  │
│  │  DC02         x.x.x.x         │  │  │  │  DC03         x.x.x.x         │  │
│  │  AD Connector → DC02/DC01       │  │  │  │  AD Connector → DC03/DC01       │  │
│  │  WorkSpaces   testuser          │  │  │  │  WorkSpaces   rochellec         │  │
│  │  S3 Mount     S: drive          │  │  │  │  S3 Mount     S: drive          │  │
│  │  Unencrypted (imageable)        │  │  │  │  Unencrypted (imageable)        │  │
│  └─────────────────────────────────┘  │  │  └─────────────────────────────────┘  │
└───────────────────────────────────────┘  └───────────────────────────────────────┘
```

---

## Current Deployments

| Region | AD Connector | WorkSpaces | DC (Local) | DC (Fallback) |
|--------|--------------|------------|------------|---------------|
| **us-east-1** | org-ad-connector-use1 | testuser | DC02 (x.x.x.x) | DC01 (x.x.x.x) |
| **ap-southeast-1** | org-ad-connector-apse1 | rochellec | DC03 (x.x.x.x) | DC01 (x.x.x.x) |

### WorkSpaces Configuration

| Setting | Value |
|---------|-------|
| Running Mode | AUTO_STOP |
| Compute Type | STANDARD |
| Root Volume | 80 GB |
| User Volume | 50 GB |
| Encryption | **Disabled** (allows imaging) |
| Default OU | OU=WorkSpaces Computers,DC=example,DC=internal |
| IP Access | x.x.x.x/xx (Allow all) |

---

## Directory Structure

```
org-workspaces-vdi/account-111122223333-account-xxxxxxxxxxxx/
├── README.md                     # This file
├── modules/                      # Shared Terraform modules
│   ├── ad-connector/             # AWS AD Connector
│   ├── workspaces/               # WorkSpaces instances
│   └── workspaces-directory/     # WorkSpaces Directory registration
├── ap-southeast-1/               # Singapore/Manila deployment
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   ├── secrets.tf
│   ├── s3-installers.tf          # S3 bucket for software
│   └── ansible/
│       └── playbooks/            # WorkSpaces configuration
├── us-east-1/                    # Virginia deployment
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   ├── secrets.tf
│   └── ansible/
│       └── playbooks/            # WorkSpaces configuration
└── docs/
    └── RUNBOOK-User-Provisioning.md
```

---

## Prerequisites

Before deploying, ensure:

1. **VPC Infrastructure** deployed:
   - `org-aws-networking/us-east-1`
   - `org-aws-networking/ap-southeast-1`

2. **Domain Controllers** running:
   - DC01 (us-east-2, x.x.x.x) - PDC
   - DC02 (us-east-1, x.x.x.x)
   - DC03 (ap-southeast-1, x.x.x.x)

3. **Service Account** in AD:
   - `svc_adconnector` - Password in Secrets Manager

4. **WorkSpaces OU** in AD:
   - `OU=WorkSpaces Computers,DC=example,DC=internal`
   - GPO `WorkSpaces-LocalAdmins` linked (adds users to local Administrators)

5. **AD Users** exist for WorkSpaces provisioning

---

## Deployment

### AP-Southeast-1 (Deploy First)

Creates S3 bucket for software installers shared by both regions.

```bash
cd ~/Repos/cloud_infrastructure/org-workspaces-vdi/account-111122223333-account-xxxxxxxxxxxx/ap-southeast-1
terraform init
terraform plan
terraform apply
```

### US-East-1

```bash
cd ~/Repos/cloud_infrastructure/org-workspaces-vdi/account-111122223333-account-xxxxxxxxxxxx/us-east-1
terraform init
terraform plan
terraform apply
```

> **Note:** US-East-1 WorkSpaces requires subnets in specific AZs (use1-az2, use1-az4, use1-az6).
> The Terraform code uses management subnets in us-east-1b and us-east-1c which are in supported AZs.

---

## Adding WorkSpaces Users

### Step 1: Create AD User

```bash
# On DC01 via SSM
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-xxxxxxxxxxxxxxxxx \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["New-ADUser -Name \"John Smith\" -SamAccountName jsmith -UserPrincipalName jsmith@example.internal -AccountPassword (ConvertTo-SecureString \"TempPass123!\" -AsPlainText -Force) -Enabled $true -Path \"CN=Users,DC=example,DC=internal\"","Write-Output \"User created\""]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text
```

### Step 2: Add to terraform.tfvars

Edit the appropriate region's `terraform.tfvars`:

```hcl
workspaces_users = ["jsmith"]
```

### Step 3: Deploy WorkSpace

```bash
terraform apply
```

### Step 4: Reboot to Apply GPO

```bash
# Get WorkSpace ID
ws_id=$(aws workspaces describe-workspaces --region us-east-1 --query "Workspaces[?UserName=='jsmith'].WorkspaceId" --output text)
aws workspaces reboot-workspaces --reboot-workspace-requests WorkspaceId=$ws_id --region us-east-1
```

### Step 5: Get Registration Code

```bash
aws workspaces describe-workspace-directories --region us-east-1 --query "Directories[0].RegistrationCode" --output text
```

---

## S3 Software Installers

Both regions share a single S3 bucket mounted as S: drive on WorkSpaces.

| Item | Value |
|------|-------|
| Bucket | org-workspace-vdi-installs |
| Region | ap-southeast-1 |
| Mount | S: drive via rclone |
| IAM User | workspaces-s3-sync |
| Credentials Secret | org-workspaces-s3-sync-credentials |

### S3 Credentials

```bash
aws secretsmanager get-secret-value --region us-east-2 \
  --secret-id org-workspaces-s3-sync-credentials \
  --query SecretString --output text | jq .
```

### Rclone Configuration (on WorkSpace)

```powershell
# Create config
$cfg = @"
[s3-installers]
type = s3
provider = AWS
access_key_id = REPLACE_WITH_AWS_ACCESS_KEY_ID
secret_access_key = REPLACE_WITH_AWS_SECRET_ACCESS_KEY
region = us-east-1
"@
$cfg | Out-File -FilePath D:\rclone\rclone.conf -Encoding ASCII -Force

# Create scheduled task
$action = New-ScheduledTaskAction -Execute "D:\rclone\rclone.exe" -Argument "mount s3-installers:org-workspace-vdi-installs S: --config D:\rclone\rclone.conf --vfs-cache-mode full --log-file D:\rclone\mount.log"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "RcloneS3Mount" -Action $action -Trigger $trigger -Principal $principal -Force

# Start now
Start-ScheduledTask -TaskName "RcloneS3Mount"
```

### Manage S3 Mount

```powershell
# Stop mount
Stop-ScheduledTask -TaskName "RcloneS3Mount"
taskkill /IM rclone.exe /F

# Start mount
Start-ScheduledTask -TaskName "RcloneS3Mount"
```

---

## Local Admin Access

GPO `WorkSpaces-LocalAdmins` grants local administrator access to specified users.

**Linked to:** `OU=WorkSpaces Computers,DC=example,DC=internal`

### Add User to Local Admins

Edit GPO on DC01 to add users:

```powershell
# View current GPO
Get-GPO -Name "WorkSpaces-LocalAdmins"

# To add users, edit the Groups.xml in SYSVOL or use GPMC
```

---

## Troubleshooting

### Check WorkSpace Status

```bash
# US-East-1
aws workspaces describe-workspaces --region us-east-1 --query "Workspaces[*].[WorkspaceId,UserName,State,ComputerName]" --output table

# AP-Southeast-1
aws workspaces describe-workspaces --region ap-southeast-1 --query "Workspaces[*].[WorkspaceId,UserName,State,ComputerName]" --output table
```

### Check AD Connector Status

```bash
# US-East-1
aws ds describe-directories --region us-east-1 --query "DirectoryDescriptions[*].[DirectoryId,Name,Stage]" --output table

# AP-Southeast-1
aws ds describe-directories --region ap-southeast-1 --query "DirectoryDescriptions[*].[DirectoryId,Name,Stage]" --output table
```

### Reboot WorkSpace

```bash
# By WorkSpace ID
aws workspaces reboot-workspaces --reboot-workspace-requests WorkspaceId=ws-xxxxx --region us-east-1

# By username
ws_id=$(aws workspaces describe-workspaces --region us-east-1 --query "Workspaces[?UserName=='testuser'].WorkspaceId" --output text)
aws workspaces reboot-workspaces --reboot-workspace-requests WorkspaceId=$ws_id --region us-east-1
```

### WorkSpace Domain Join Failed

1. Verify svc_adconnector password matches Secrets Manager
2. Check OU exists: `OU=WorkSpaces Computers,DC=example,DC=internal`
3. Verify svc_adconnector has permissions to join computers to OU
4. Check DC connectivity from AD Connector subnets

### S3 Mount Not Working

```powershell
# Check if rclone is running
Get-Process rclone

# Check mount log
Get-Content D:\rclone\mount.log -Tail 30

# Verify config
Get-Content D:\rclone\rclone.conf

# Check WinFsp service
Get-Service WinFsp*
```

---

## Key Resources

### Domain Controllers

| DC | IP | Region | Instance ID |
|----|-----|--------|-------------|
| DC01 (PDC) | x.x.x.x | us-east-2 | i-xxxxxxxxxxxxxxxxx |
| DC02 | x.x.x.x | us-east-1 | i-xxxxxxxxxxxxxxxxx |
| DC03 | x.x.x.x | ap-southeast-1 | i-xxxxxxxxxxxxxxxxx |

### AD Domain

| Property | Value |
|----------|-------|
| Domain | example.internal |
| NetBIOS | ORG |
| Rebuilt | December 2025 |

### Credentials

All credentials in AWS Secrets Manager (us-east-2):

| Secret | Purpose |
|--------|---------|
| org-infrastructure/credentials | AD admin, service accounts |
| org-workspaces-s3-sync-credentials | S3 access for rclone |

---

## Terraform State

| Region | Key |
|--------|-----|
| us-east-1 | workspaces/us-east-1/terraform.tfstate |
| ap-southeast-1 | workspaces/ap-southeast-1/terraform.tfstate |

**Bucket:** org-terraform-state-account-111122223333-xxxxxxxxxxxx

---

## Related Projects

| Project | Purpose |
|---------|---------|
| org-aws-networking | VPCs, Firewalls, Transit Gateways |
| org-aws-ActiveDirectory | Domain Controllers (DC01, DC02, DC03) |

---

## Changelog

### 2025-12-16

- US-East-1 WorkSpaces deployed (testuser)
- Added third management subnet (x.x.x.x/xx) for WorkSpaces AZ requirements
- Updated documentation with current state

### 2025-12-15

- AP-Southeast-1 WorkSpaces rebuilt (rochellec)
- AD Connectors recreated after domain rebuild
- Encryption disabled for imaging capability
- S3 rclone mount configured
- Local admin GPO created
