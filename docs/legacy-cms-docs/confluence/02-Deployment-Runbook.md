# Deployment Runbook

## Prerequisites
Install and configure:
- Terraform
- Terragrunt
- AWS CLI v2
- Authenticated AWS credentials with access to account `111122223333`

Reference: `PREREQUISITES.md`

## Recommended Deployment Order
1. Backend (Terraform state infrastructure)
2. Installs S3 bucket
3. WorkSpaces personal tiers
4. WorkSpaces pools

## Backend Deployment
{code:bash}
cd backend/us-east-1
terraform init
terraform plan
terraform apply
{code}

## Installs Bucket Deployment
{code:bash}
cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/installs-bucket
terragrunt init
terragrunt plan
terragrunt apply
{code}

## Personal Tier Deployments
### Standard
{code:bash}
cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/standard
terragrunt init
terragrunt plan
terragrunt apply
{code}

### SOC
{code:bash}
cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/soc
terragrunt init
terragrunt plan
terragrunt apply
{code}

### Dev
{code:bash}
cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/dev
terragrunt init
terragrunt plan
terragrunt apply
{code}

## Pool Deployments
Before pool apply:
- Confirm `pool_directory_id = wsd-00000000` in `common.hcl`
- Set `saml_xml_secret_arn` in each pool `terragrunt.hcl`

### Standard Pool
{code:bash}
cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/standard-pool
terragrunt init
terragrunt plan
terragrunt apply
{code}

### SOC Pool
{code:bash}
cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/soc-pool
terragrunt init
terragrunt plan
terragrunt apply
{code}

### Dev Pool
{code:bash}
cd live/aws/aws-workspaces-platform/account-111122223333/us-east-1/dev-pool
terragrunt init
terragrunt plan
terragrunt apply
{code}

## Interactive Script Option
Use root scripts to guide deploy choice:
- `./run-add-workspace.sh` (macOS/Linux)
- `.\run-add-workspace.ps1` (Windows)

Script prompts:
1. Deployment type: Personal Workspace or Workspace Pool
2. Tier: Standard, SOC, Dev

## Post-Deployment Validation
- Confirm Terraform outputs are present.
- Verify WorkSpaces state in AWS console.
- Validate target users/sessions and bundle assignment.
- Confirm tags and naming standards on created resources.
