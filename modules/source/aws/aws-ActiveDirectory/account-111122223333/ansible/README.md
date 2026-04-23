# Generic AWS AD - Ansible Automation

Ansible playbooks for configuring self-managed Active Directory domain controllers
using AWS Systems Manager (SSM) Run Command.

**Last Updated:** December 16, 2025

## Important Notes

### Architecture
All playbooks run from **localhost** and use **AWS CLI SSM commands** to execute
PowerShell on the Windows servers. This approach is more reliable than the
`aws_ssm` connection plugin.

### Password Requirements
**CRITICAL:** Passwords should NOT contain special shell characters like `! $ \ \``
Use alphanumeric with `@` or `#` if needed. Example: `P@ssw0rd123`

### SSM Command Pattern
Always chain send-command and get-command-invocation with sleep:
```bash
cmd_id=$(aws ssm send-command --region <region> --instance-ids <id> ...) && sleep 5 && aws ssm get-command-invocation ...
```

---

## Instance IDs (December 2025)

| Server | Instance ID | Region | IP Address | Site |
|--------|-------------|--------|------------|------|
| DC01 | i-xxxxxxxxxxxxxxxxx | us-east-2 | x.x.x.x | US-East-2 |
| DC02 | i-xxxxxxxxxxxxxxxxx | us-east-1 | x.x.x.x | US-East-1 |
| DC03 | i-xxxxxxxxxxxxxxxxx | ap-southeast-1 | x.x.x.x | AP-Southeast-1 |

---

## Quick Start

```bash
cd ~/Repos/cloud_infrastructure/org-aws-ActiveDirectory/account-111122223333-account-xxxxxxxxxxxx/ansible

# Run playbooks in order
ansible-playbook playbooks/01-prepare-servers-ssm.yml -v
ansible-playbook playbooks/02-promote-dc01-ssm.yml -v
ansible-playbook playbooks/03-promote-dc02-ssm.yml -v
ansible-playbook playbooks/04-configure-sites-ssm.yml -v
ansible-playbook playbooks/05-promote-dc03-ssm.yml -v
ansible-playbook playbooks/06-create-service-accounts-ssm.yml -v
```

---

## Playbooks

| Playbook | Description | Duration |
|----------|-------------|----------|
| `01-prepare-servers-ssm.yml` | Install AD DS features on all DCs | ~10 min |
| `02-promote-dc01-ssm.yml` | Create example.internal forest on DC01 | ~15 min |
| `03-promote-dc02-ssm.yml` | Join and promote DC02 | ~10 min |
| `04-configure-sites-ssm.yml` | Create AD sites and subnets | ~2 min |
| `05-promote-dc03-ssm.yml` | Join and promote DC03 (cross-region) | ~15 min |
| `06-create-service-accounts-ssm.yml` | Create service accounts | ~2 min |

---

## Credentials

All credentials stored in **AWS Secrets Manager**:

- **Secret:** `org-infrastructure/credentials`
- **Region:** `us-east-2`

### Loading Secrets in Playbooks

Playbooks that need credentials should include `load-secrets.yml`:

```yaml
tasks:
  - name: Load secrets from AWS Secrets Manager
    include_tasks: load-secrets.yml
    
  # Now use: {{ ad_admin_password }}, {{ svc_adconnector_password }}, etc.
```

### Available Credential Variables

| Variable | Description |
|----------|-------------|
| `ad_admin_password` | Domain Administrator password |
| `ad_password` | Alias for ad_admin_password |
| `ad_safe_mode_password` | DSRM password |
| `svc_workspaces_password` | svc_workspaces service account |
| `svc_adconnector_password` | svc_adconnector service account |

### View/Update Secrets

```bash
# View current credentials
aws secretsmanager get-secret-value \
  --region us-east-2 \
  --secret-id org-infrastructure/credentials \
  --query SecretString --output text | jq .
```

---

## Service Accounts

| Account | Username | Purpose |
|---------|----------|---------|
| Domain Admin | ORG\Administrator | Domain administration |
| AD Connector | svc_adconnector | AWS AD Connector |
| WorkSpaces | svc_workspaces | AWS WorkSpaces |

---

## Troubleshooting

### Check SSM Agent Status

```bash
# US-East-2
aws ssm describe-instance-information --region us-east-2 --query "InstanceInformationList[*].[InstanceId,PingStatus]" --output table

# US-East-1
aws ssm describe-instance-information --region us-east-1 --query "InstanceInformationList[*].[InstanceId,PingStatus]" --output table

# AP-Southeast-1
aws ssm describe-instance-information --region ap-southeast-1 --query "InstanceInformationList[*].[InstanceId,PingStatus]" --output table
```

### Run Manual PowerShell Commands

```bash
# DC01 (us-east-2)
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-xxxxxxxxxxxxxxxxx --document-name "AWS-RunPowerShellScript" --parameters 'commands=["Get-ADDomain"]' --output json | jq -r '.Command.CommandId') && sleep 5 && aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text

# DC02 (us-east-1)
cmd_id=$(aws ssm send-command --region us-east-1 --instance-ids i-xxxxxxxxxxxxxxxxx --document-name "AWS-RunPowerShellScript" --parameters 'commands=["Get-ADDomainController -Identity $env:COMPUTERNAME"]' --output json | jq -r '.Command.CommandId') && sleep 5 && aws ssm get-command-invocation --region us-east-1 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text

# DC03 (ap-southeast-1)
cmd_id=$(aws ssm send-command --region ap-southeast-1 --instance-ids i-xxxxxxxxxxxxxxxxx --document-name "AWS-RunPowerShellScript" --parameters 'commands=["Get-ADDomainController -Identity $env:COMPUTERNAME"]' --output json | jq -r '.Command.CommandId') && sleep 5 && aws ssm get-command-invocation --region ap-southeast-1 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text
```

### Check AD Replication

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-xxxxxxxxxxxxxxxxx --document-name "AWS-RunPowerShellScript" --parameters 'commands=["repadmin /replsummary"]' --output json | jq -r '.Command.CommandId') && sleep 10 && aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text
```

### List All Domain Controllers

```bash
cmd_id=$(aws ssm send-command --region us-east-2 --instance-ids i-xxxxxxxxxxxxxxxxx --document-name "AWS-RunPowerShellScript" --parameters 'commands=["Get-ADDomainController -Filter * | Select-Object Name,IPv4Address,Site | Format-Table"]' --output json | jq -r '.Command.CommandId') && sleep 5 && aws ssm get-command-invocation --region us-east-2 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text
```

### Test Connectivity Between DCs

```bash
# From DC02 to DC01
cmd_id=$(aws ssm send-command --region us-east-1 --instance-ids i-xxxxxxxxxxxxxxxxx --document-name "AWS-RunPowerShellScript" --parameters 'commands=["Test-NetConnection -ComputerName x.x.x.x -Port 389"]' --output json | jq -r '.Command.CommandId') && sleep 10 && aws ssm get-command-invocation --region us-east-1 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text

# From DC03 to DC01
cmd_id=$(aws ssm send-command --region ap-southeast-1 --instance-ids i-xxxxxxxxxxxxxxxxx --document-name "AWS-RunPowerShellScript" --parameters 'commands=["Test-NetConnection -ComputerName x.x.x.x -Port 389"]' --output json | jq -r '.Command.CommandId') && sleep 10 && aws ssm get-command-invocation --region ap-southeast-1 --command-id $cmd_id --instance-id i-xxxxxxxxxxxxxxxxx --query "StandardOutputContent" --output text
```

---

## Lessons Learned

1. **Use `netdom join` instead of `Add-Computer`** - More reliable for domain joins
2. **Reset Administrator password** on DC01 before joining other DCs
3. **Avoid special characters** in passwords (`! $ \` \`) to prevent shell escaping issues
4. **Deploy firewall rules first** - SSM requires HTTPS access to AWS endpoints
5. **Use AWS CLI directly** - More reliable than aws_ssm connection plugin
6. **Set DNS to DC01** before attempting domain join
7. **Chain SSM commands** - Always chain send-command and get-command-invocation with sleep

---

## File Structure

```
ansible/
├── ansible.cfg                 # Ansible configuration
├── README.md                   # This file
├── .gitignore                  # Excludes secrets.yml files
└── playbooks/
    ├── vars/
    │   └── main.yml            # DC instance IDs, IPs, regions
    ├── load-secrets.yml        # Include file to load AWS secrets
    ├── 01-prepare-servers-ssm.yml
    ├── 02-promote-dc01-ssm.yml
    ├── 03-promote-dc02-ssm.yml
    ├── 04-configure-sites-ssm.yml
    ├── 05-promote-dc03-ssm.yml
    ├── 06-create-service-accounts-ssm.yml
    └── user-management/
        ├── README.md
        ├── users.yml
        ├── manage-users.yml
        └── list-users.yml
```
