# AD User Management

Ansible playbooks for managing Active Directory users in the example.internal domain.

**Last Updated:** December 16, 2025

---

## Quick Start

```bash
cd ~/Repos/cloud_infrastructure/org-aws-ActiveDirectory/account-111122223333-account-xxxxxxxxxxxx/ansible

# Create users defined in users.yml
ansible-playbook playbooks/user-management/manage-users.yml

# List all users
ansible-playbook playbooks/user-management/list-users.yml
```

---

## Files

| File | Description |
|------|-------------|
| `users.yml` | User definitions - add users here |
| `manage-users.yml` | Main playbook for create/delete/disable/enable operations |
| `list-users.yml` | Query existing AD users |

---

## Managing Users

### Define Users in users.yml

```yaml
ad_users:
  - username: jsmith
    display_name: "John Smith"
    password: "TempP@ss123!"
    email: "jsmith@example.internal"
    department: "Engineering"
    title: "Software Engineer"
    groups:
      - "Domain Users"
      - "VPN Users"
    must_change_password: true
```

### User Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `username` | Yes | - | SAM account name (login) |
| `display_name` | Yes | - | Full display name |
| `password` | Yes | - | Initial password |
| `email` | No | username@example.internal | Email address |
| `ou` | No | CN=Users,DC=example,DC=internal | Organizational Unit |
| `groups` | No | [] | List of AD groups |
| `description` | No | "" | User description |
| `department` | No | "" | Department name |
| `title` | No | "" | Job title |
| `must_change_password` | No | true | Force password change at first login |
| `password_never_expires` | No | false | Password never expires |
| `enabled` | No | true | Account enabled |

---

## Actions

### Create/Update Users
```bash
ansible-playbook playbooks/user-management/manage-users.yml
```

### Delete Users
```bash
ansible-playbook playbooks/user-management/manage-users.yml -e "action=delete"
```

### Disable Users
```bash
ansible-playbook playbooks/user-management/manage-users.yml -e "action=disable"
```

### Enable Users
```bash
ansible-playbook playbooks/user-management/manage-users.yml -e "action=enable"
```

### Reset Passwords
```bash
ansible-playbook playbooks/user-management/manage-users.yml -e "action=reset_password"
```

---

## Ad-Hoc User Creation

Create a single user without editing users.yml:

```bash
ansible-playbook playbooks/user-management/manage-users.yml -e '{
  "ad_users": [{
    "username": "newuser",
    "display_name": "New User",
    "password": "TempP@ss123!",
    "groups": ["Domain Users"]
  }]
}'
```

### Quick SSM Command (bypasses Ansible)

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-xxxxxxxxxxxxxxxxx \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["New-ADUser -Name \"John Smith\" -SamAccountName jsmith -UserPrincipalName jsmith@example.internal -AccountPassword (ConvertTo-SecureString \"TempPass123!\" -AsPlainText -Force) -Enabled $true -Path \"CN=Users,DC=example,DC=internal\"","Write-Output \"User created\""]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text
```

---

## Listing Users

```bash
# All users
ansible-playbook playbooks/user-management/list-users.yml

# Users in specific OU
ansible-playbook playbooks/user-management/list-users.yml \
  -e "search_base='OU=Admins,DC=example,DC=internal'"

# Search by name
ansible-playbook playbooks/user-management/list-users.yml \
  -e "filter='Name -like \"*john*\"'"
```

### Quick SSM Query

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-xxxxxxxxxxxxxxxxx \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Get-ADUser -Filter * | Select-Object Name,SamAccountName,Enabled | Format-Table"]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text
```

---

## Password Requirements

Default AD password policy requires:
- Minimum 7 characters
- At least 3 of: uppercase, lowercase, number, special character
- Cannot contain username

---

## Key Instance IDs

| Server | Instance ID | Region | IP |
|--------|-------------|--------|-----|
| DC01 (PDC) | i-xxxxxxxxxxxxxxxxx | us-east-2 | x.x.x.x |
| DC02 | i-xxxxxxxxxxxxxxxxx | us-east-1 | x.x.x.x |
| DC03 | i-xxxxxxxxxxxxxxxxx | ap-southeast-1 | x.x.x.x |

---

## Troubleshooting

### Check if user exists

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-xxxxxxxxxxxxxxxxx \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Get-ADUser -Identity username -Properties * | Select-Object Name,SamAccountName,Enabled,PasswordLastSet"]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text
```

### Reset user password

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-xxxxxxxxxxxxxxxxx \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Set-ADAccountPassword -Identity username -Reset -NewPassword (ConvertTo-SecureString \"NewPass123!\" -AsPlainText -Force)","Set-ADUser -Identity username -ChangePasswordAtLogon $false","Write-Output \"Password reset\""]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text
```

### Enable/Disable user

```bash
# Disable
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-xxxxxxxxxxxxxxxxx \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Disable-ADAccount -Identity username","Write-Output \"User disabled\""]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text

# Enable
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-xxxxxxxxxxxxxxxxx \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Enable-ADAccount -Identity username","Write-Output \"User enabled\""]' \
  --output json | jq -r '.Command.CommandId') && sleep 5 && \
aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text
```
