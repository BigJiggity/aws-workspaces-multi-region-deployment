# Generic WorkSpaces VDI - US-East-1 Ansible Configuration

Ansible playbooks for configuring AWS WorkSpaces in us-east-1.

**Last Updated:** December 16, 2025

---

## Overview

WorkSpaces in us-east-1 authenticate against local DC02 (x.x.x.x) with fallback to DC01 (x.x.x.x) via Transit Gateway peering.

```
us-east-1 WorkSpaces
     ↓
AD Connector → DC02 (x.x.x.x, local) + DC01 (x.x.x.x, fallback via TGW)
     ↓
WorkSpace: testuser (unencrypted, imageable)
S3 Mount: S: drive via rclone
```

---

## Current State

| Component | Value |
|-----------|-------|
| WorkSpace User | testuser |
| AD Connector | org-ad-connector-use1 |
| Local DC | DC02 (x.x.x.x) |
| Fallback DC | DC01 (x.x.x.x) |
| WorkSpaces OU | OU=WorkSpaces Computers,DC=example,DC=internal |
| Local Admin GPO | WorkSpaces-LocalAdmins |
| S3 Bucket | org-workspace-vdi-installs |
| S3 Mount | S: drive via rclone |

---

## Directory Structure

```
ansible/
├── README.md             # This file
├── ansible.cfg           # Ansible configuration
└── playbooks/
    ├── vars/
    │   └── main.yml      # Central variables
    └── 06-configure-s3-rclone-mount-ssm.yml
```

---

## S3 Mount Configuration

WorkSpaces use rclone to mount S3 bucket as S: drive.

### Prerequisites (on WorkSpace)

1. **WinFsp** installed (D:\WinFsp)
2. **rclone** installed (D:\rclone)

### Manual Configuration (via RDP)

Run as Administrator on the WorkSpace:

```powershell
# Create rclone config
$cfg = @"
[s3-installers]
type = s3
provider = AWS
access_key_id = REPLACE_WITH_AWS_ACCESS_KEY_ID
secret_access_key = REPLACE_WITH_AWS_SECRET_ACCESS_KEY
region = us-east-1
"@
$cfg | Out-File -FilePath D:\rclone\rclone.conf -Encoding ASCII -Force

# Create scheduled task for startup
$action = New-ScheduledTaskAction -Execute "D:\rclone\rclone.exe" -Argument "mount s3-installers:org-workspace-vdi-installs S: --config D:\rclone\rclone.conf --vfs-cache-mode full --log-file D:\rclone\mount.log"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "RcloneS3Mount" -Action $action -Trigger $trigger -Principal $principal -Force

# Start mount now
Start-ScheduledTask -TaskName "RcloneS3Mount"

# Verify
Start-Sleep -Seconds 5
if (Test-Path S:) { Write-Output "SUCCESS: S: drive mounted" } else { Get-Content D:\rclone\mount.log -Tail 20 }
```

### Manage S3 Mount

```powershell
# Stop mount
Stop-ScheduledTask -TaskName "RcloneS3Mount"
taskkill /IM rclone.exe /F

# Restart mount
Start-ScheduledTask -TaskName "RcloneS3Mount"

# Check status
Get-ScheduledTask -TaskName "RcloneS3Mount" | Select-Object State
Get-Process rclone -ErrorAction SilentlyContinue
```

---

## Local Admin Access

GPO `WorkSpaces-LocalAdmins` is linked to `OU=WorkSpaces Computers,DC=example,DC=internal` and grants local administrator access.

To add users, edit the GPO on DC01 or add users via Group Policy Preferences.

---

## Key Instance IDs

| Server | Instance ID | Region | IP |
|--------|-------------|--------|-----|
| DC01 | i-xxxxxxxxxxxxxxxxx | us-east-2 | x.x.x.x |
| DC02 | i-xxxxxxxxxxxxxxxxx | us-east-1 | x.x.x.x |

---

## Troubleshooting

### Check WorkSpace Status

```bash
aws workspaces describe-workspaces --region us-east-1 --query "Workspaces[*].[WorkspaceId,UserName,State,ComputerName]" --output table
```

### Reboot WorkSpace

```bash
ws_id=$(aws workspaces describe-workspaces --region us-east-1 --query "Workspaces[?UserName=='testuser'].WorkspaceId" --output text)
aws workspaces reboot-workspaces --reboot-workspace-requests WorkspaceId=$ws_id --region us-east-1
```

### S3 Mount Issues

```powershell
# Check mount log
Get-Content D:\rclone\mount.log -Tail 30

# Verify config
Get-Content D:\rclone\rclone.conf

# Check WinFsp
Get-Service WinFsp*
```

---

## Notes

- WorkSpaces don't have SSM agent by default - configuration must be done via RDP
- S3 credentials are stored in Secrets Manager: `org-workspaces-s3-sync-credentials`
- rclone/WinFsp installed on D: drive (user volume) to persist across reboots
