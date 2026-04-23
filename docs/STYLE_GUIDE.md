# Style Guide

## Terragrunt Structure
- Keep deployable units under `live/aws/<stack>/<account>/<region>/<unit>/terragrunt.hcl`.
- Keep reusable Terraform source under `modules/source/aws/<stack>/<account>/<region>/...`.
- Keep shared metadata in:
  - `root.hcl`
  - `live/global.hcl`
  - `live/aws/provider.hcl`
  - stack/account/common metadata files

## Configuration Rules
- Treat `config/deployment.env` as the source of truth for account/region/naming settings.
- Use `scripts/configure-project.sh` to regenerate/update config-managed files.
- Avoid hardcoding account IDs and region values in new files.

## Terraform/Terragrunt Practices
- Run `terraform fmt -recursive` before commit.
- Run `terragrunt hcl fmt --working-dir .` before commit.
- Each unit should have a unique remote state key.
- Keep module inputs explicit; avoid hidden defaults for security-sensitive settings.

## Security and Compliance
- No secrets in source control.
- Use AWS Secrets Manager for sensitive values.
- Use least-privilege IAM for deploy roles and service roles.
