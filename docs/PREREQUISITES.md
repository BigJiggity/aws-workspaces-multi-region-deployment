# Prerequisites

## Required Tools
- Terraform >= 1.5
- Terragrunt
- AWS CLI v2
- Bash (for `scripts/*.sh`)

## AWS Access
- Active AWS credentials with permissions for:
  - S3, DynamoDB, KMS (backend)
  - WorkSpaces resources for selected deployment stacks

## Initial Setup
1. Copy config template:

```bash
cp config/deployment.env.example config/deployment.env
```

2. Update `config/deployment.env` with your account, region, and backend values.

3. Apply repository configuration:

```bash
./scripts/configure-project.sh --config config/deployment.env
```

4. Run preflight validation:

```bash
./scripts/preflight.sh --config config/deployment.env
```
