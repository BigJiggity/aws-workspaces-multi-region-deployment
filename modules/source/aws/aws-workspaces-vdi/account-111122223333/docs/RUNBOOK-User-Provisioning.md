# RUNBOOK: WorkSpaces User Provisioning

**Document Version:** 1.0  
**Last Updated:** December 16, 2025  
**Owner:** System Architects  
**AWS Account:** 111122223333  
**Domain:** example.internal

---

## 1. Overview

This runbook provides step-by-step instructions for provisioning a new AWS WorkSpace for a user. The process involves creating an Active Directory user account, adding them to Terraform configuration, deploying the WorkSpace, and configuring post-deployment settings.

### 1.1 Architecture Summary

| Region | Domain Controller | AD Connector |
|--------|-------------------|--------------|
| us-east-1 | DC02 (x.x.x.x) | org-ad-connector-use1 |
| ap-southeast-1 | DC03 (x.x.x.x) | org-ad-connector-apse1 |

### 1.2 Time Estimate

**Total provisioning time: 15-25 minutes**

- AD User Creation: 2 minutes
- Terraform Deployment: 10-15 minutes
- Post-Deployment Configuration: 5-10 minutes

---

## 2. Prerequisites

### 2.1 Required Access

1. AWS CLI configured with credentials for account 111122223333
2. Access to Terraform state bucket: org-terraform-state-account-111122223333-111122223333
3. Git access to cloud_infrastructure repository
4. Terraform >= 1.5.0 installed

### 2.2 Required Information

Gather the following information before starting:

| Field | Description |
|-------|-------------|
| **Username** | SAM account name (e.g., jsmith) - max 20 characters |
| **Display Name** | Full name (e.g., John Smith) |
| **Initial Password** | Temporary password (user will change on first login) |
| **Target Region** | us-east-1 (US) or ap-southeast-1 (Manila) |
| **Local Admin Required?** | Yes/No - determines if user needs admin rights on WorkSpace |

> ⚠️ **Warning:** Password must be at least 8 characters with uppercase, lowercase, and number. Avoid special characters like `! $ \ \`` in passwords.

---

## 3. Phase 1: Create Active Directory User

Create the user account in Active Directory using SSM to run PowerShell on DC01.

### 3.1 Create User via SSM Command

Replace the placeholder values (`USERNAME`, `DISPLAY_NAME`, `PASSWORD`) in the command below:

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-0d74f088f44fc088b \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["New-ADUser -Name \"DISPLAY_NAME\" -SamAccountName USERNAME -UserPrincipalName USERNAME@example.internal -AccountPassword (ConvertTo-SecureString \"PASSWORD\" -AsPlainText -Force) -Enabled $true -Path \"CN=Users,DC=example,DC=internal\"", "Write-Output \"User USERNAME created successfully\""]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id \
  --instance-id i-0d74f088f44fc088b --query "StandardOutputContent" --output text
```

**Example with real values:**

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-0d74f088f44fc088b \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["New-ADUser -Name \"John Smith\" -SamAccountName jsmith -UserPrincipalName jsmith@example.internal -AccountPassword (ConvertTo-SecureString \"TempPass123\" -AsPlainText -Force) -Enabled $true -Path \"CN=Users,DC=example,DC=internal\"", "Write-Output \"User jsmith created successfully\""]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id \
  --instance-id i-0d74f088f44fc088b --query "StandardOutputContent" --output text
```

✅ **Expected output:** `User jsmith created successfully`

### 3.2 Verify User Creation

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-0d74f088f44fc088b \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Get-ADUser -Identity USERNAME | Select Name,SamAccountName,Enabled"]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id \
  --instance-id i-0d74f088f44fc088b --query "StandardOutputContent" --output text
```

---

## 4. Phase 2: Add to Local Admins Group (Optional)

If the user requires local administrator access on their WorkSpace, add them to the WorkSpaces-LocalAdmins group.

> ℹ️ **Note:** Skip this phase if the user does not need local admin rights.

### 4.1 Add User to WorkSpaces-LocalAdmins Group

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-0d74f088f44fc088b \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Add-ADGroupMember -Identity \"WorkSpaces-LocalAdmins\" -Members USERNAME", "Write-Output \"User added to WorkSpaces-LocalAdmins\""]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id \
  --instance-id i-0d74f088f44fc088b --query "StandardOutputContent" --output text
```

### 4.2 Verify Group Membership

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-0d74f088f44fc088b \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Get-ADGroupMember -Identity \"WorkSpaces-LocalAdmins\" | Select Name"]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id \
  --instance-id i-0d74f088f44fc088b --query "StandardOutputContent" --output text
```

---

## 5. Phase 3: Update Terraform Configuration

Add the new user to the Terraform configuration for the target region.

### 5.1 Navigate to the Target Region

**For US-East-1 (US users):**
```bash
cd ~/Repos/cloud_infrastructure/org-workspaces-vdi/account-111122223333/us-east-1
```

**For AP-Southeast-1 (Manila users):**
```bash
cd ~/Repos/cloud_infrastructure/org-workspaces-vdi/account-111122223333/ap-southeast-1
```

### 5.2 Edit terraform.tfvars

1. Open the terraform.tfvars file:
   ```bash
   vim terraform.tfvars
   ```

2. Find the `workspaces_users` list and add the new username:
   ```hcl
   # Before
   workspaces_users = ["testuser"]
   
   # After
   workspaces_users = ["testuser", "jsmith"]
   ```

3. Save and exit the file.

> ⚠️ **Warning:** Ensure the username exactly matches the SAM account name created in AD (case-sensitive).

---

## 6. Phase 4: Deploy the WorkSpace

### 6.1 Initialize and Plan

1. Initialize Terraform (if not already done):
   ```bash
   terraform init
   ```

2. Review the planned changes:
   ```bash
   terraform plan
   ```

   Expected output should show:
   ```
   # module.workspaces.aws_workspaces_workspace.workspaces["jsmith"] will be created
   ```

### 6.2 Apply Changes

1. Apply the Terraform configuration:
   ```bash
   terraform apply
   ```

2. Type `yes` when prompted to confirm.

> ℹ️ **Note:** WorkSpace provisioning takes 10-15 minutes. Wait for Terraform to complete.

### 6.3 Verify Deployment

**For US-East-1:**
```bash
aws workspaces describe-workspaces --region us-east-1 \
  --query "Workspaces[?UserName=='jsmith'].[WorkspaceId,UserName,State]" --output table
```

**For AP-Southeast-1:**
```bash
aws workspaces describe-workspaces --region ap-southeast-1 \
  --query "Workspaces[?UserName=='jsmith'].[WorkspaceId,UserName,State]" --output table
```

✅ **Expected State:** `AVAILABLE`

---

## 7. Phase 5: Post-Deployment Configuration

### 7.1 Reboot WorkSpace to Apply GPO

Reboot the WorkSpace to apply Group Policy settings (local admin rights, if configured):

```bash
# Get WorkSpace ID
ws_id=$(aws workspaces describe-workspaces --region REGION \
  --query "Workspaces[?UserName=='USERNAME'].WorkspaceId" --output text)

# Reboot
aws workspaces reboot-workspaces --region REGION \
  --reboot-workspace-requests WorkspaceId=$ws_id
```

### 7.2 Get Registration Code

Provide the registration code to the user for WorkSpaces client setup:

**For US-East-1:**
```bash
aws workspaces describe-workspace-directories --region us-east-1 \
  --query "Directories[0].RegistrationCode" --output text
```

**For AP-Southeast-1:**
```bash
aws workspaces describe-workspace-directories --region ap-southeast-1 \
  --query "Directories[0].RegistrationCode" --output text
```

### 7.3 Configure S3 Mount (Via RDP)

#### Step 1: Retrieve S3 Credentials from Secrets Manager

First, retrieve the S3 credentials from AWS Secrets Manager (run from your local machine with AWS CLI access):

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

> ⚠️ **Security Note:** Never store these credentials in documentation or commit them to version control. Retrieve them fresh each time.

#### Step 2: Configure rclone on the WorkSpace

Connect to the WorkSpace via RDP and run the following PowerShell commands as Administrator.

**Replace `<ACCESS_KEY_ID>` and `<SECRET_ACCESS_KEY>` with the values retrieved in Step 1:**

```powershell
# Create rclone config (replace placeholders with actual credentials)
$cfg = @"
[s3-installers]
type = s3
provider = AWS
access_key_id = <ACCESS_KEY_ID>
secret_access_key = <SECRET_ACCESS_KEY>
region = us-east-1
"@
$cfg | Out-File -FilePath D:\rclone\rclone.conf -Encoding ASCII -Force

# Create scheduled task
$action = New-ScheduledTaskAction -Execute "D:\rclone\rclone.exe" `
  -Argument "mount s3-installers:org-workspace-vdi-installs S: --config D:\rclone\rclone.conf --vfs-cache-mode full --log-file D:\rclone\mount.log"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "RcloneS3Mount" -Action $action -Trigger $trigger -Principal $principal -Force

# Start mount
Start-ScheduledTask -TaskName "RcloneS3Mount"

# Verify
Start-Sleep -Seconds 5
if (Test-Path S:) { Write-Output "SUCCESS: S: drive mounted" } else { Get-Content D:\rclone\mount.log -Tail 20 }
```

> ⚠️ **Warning:** rclone and WinFsp must be installed on D: drive before running this script.

---

## 8. Phase 6: User Communication

Send the following information to the new user:

### 8.1 User Welcome Email Template

```
Subject: Your AWS WorkSpace is Ready

Hello [NAME],

Your AWS WorkSpace has been provisioned. Here's how to get started:

1. Download the WorkSpaces client: https://clients.amazonworkspaces.com/
2. Registration Code: [REGISTRATION_CODE]
3. Username: [USERNAME]
4. Temporary Password: [PASSWORD]

Please change your password upon first login.

If you have any issues, please contact IT support.

Best regards,
System Architects
```

---

## 9. Verification Checklist

Complete the following checklist to verify the provisioning was successful:

- [ ] AD user exists and is enabled
- [ ] User added to WorkSpaces-LocalAdmins (if required)
- [ ] terraform.tfvars updated with new username
- [ ] Terraform apply completed successfully
- [ ] WorkSpace state is AVAILABLE
- [ ] WorkSpace rebooted to apply GPO
- [ ] Registration code obtained
- [ ] S3 mount configured (S: drive)
- [ ] User notified with credentials and registration code

---

## 10. Troubleshooting

### 10.1 WorkSpace Stuck in PENDING

If the WorkSpace remains in PENDING state for more than 20 minutes:

1. Verify the AD user exists and is enabled
2. Check AD Connector status in AWS Console
3. Verify svc_adconnector service account credentials are correct

### 10.2 User Cannot Log In

- Verify password meets complexity requirements
- Check if account is locked out in AD
- Ensure user is logging in with correct format: `USERNAME` (not `ORG\USERNAME`)

### 10.3 S3 Mount Not Working

- Verify rclone and WinFsp are installed on D: drive
- Check `D:\rclone\mount.log` for errors
- Verify scheduled task `RcloneS3Mount` exists and is running

### 10.4 Local Admin Rights Not Working

- Verify user is in WorkSpaces-LocalAdmins group
- Reboot the WorkSpace to force GPO refresh
- Run `gpupdate /force` on the WorkSpace

---

## 11. Quick Reference

### 11.1 Key Instance IDs

| Server | Instance ID | Region / IP |
|--------|-------------|-------------|
| DC01 (PDC) | i-0d74f088f44fc088b | us-east-2 / x.x.x.x |
| DC02 | i-057c205efd2d28087 | us-east-1 / x.x.x.x |
| DC03 | i-0f2607ac2de5b1f24 | ap-southeast-1 / x.x.x.x |

### 11.2 Key Paths

| Resource | Path |
|----------|------|
| VDI (US-East-1) | `~/Repos/cloud_infrastructure/org-workspaces-vdi/account-111122223333/us-east-1/` |
| VDI (AP-SE-1) | `~/Repos/cloud_infrastructure/org-workspaces-vdi/account-111122223333/ap-southeast-1/` |
| AD Ansible | `~/Repos/cloud_infrastructure/org-aws-ActiveDirectory/account-111122223333/ansible/` |

### 11.3 S3 Configuration

| Item | Value |
|------|-------|
| Bucket | org-workspace-vdi-installs |
| Region | us-east-1 |
| Credentials | Stored in AWS Secrets Manager |

**To retrieve S3 credentials:**

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

> ⚠️ **Security:** Never hardcode credentials in documentation or scripts. Always retrieve from Secrets Manager.

---

*— End of Runbook —*
