# Standards and Well-Architected

## Objective
Define the engineering and operational standards used by this project for consistency and auditability.

## Standards Sources
- `STYLE_GUIDE.md`
- `WELL_ARCHITECTED_CHECKLIST.md`

## Terragrunt Standards
- Keep units independent and focused on one deployable concern.
- Use shared configuration from `common.hcl` for directory/subnets/backend defaults.
- Assign unique backend state key per unit.
- Prefer deterministic naming and tagging for all resources.

## Script Standards
### Shell
- Use `set -euo pipefail`.
- Validate required inputs before mutation.
- Implement cleanup paths for failed operations.

### PowerShell
- Use `$ErrorActionPreference = "Stop"`.
- Use `try/catch` around `terragrunt init/plan/apply`.
- Capture diagnostics after failure.

## Security Standards
- Do not store secrets in code.
- Use Secrets Manager for SAML metadata and credentials.
- Enforce encryption at rest and in transit for state and storage.
- Restrict network access to approved CIDRs.

## AWS Well-Architected Mapping
|| Pillar || Implementation in Project ||
| Operational Excellence | Preflight scripts, runbooks, isolated Terragrunt units |
| Security | KMS-backed encryption, Secrets Manager, least-privilege workflows |
| Reliability | State locking, deterministic backend, retryable deployment patterns |
| Performance Efficiency | Tiered bundles, pool capacity controls by workload |
| Cost Optimization | AUTO_STOP defaults, bounded pool min/max sessions |
| Sustainability | Auto-stop and right-sized bundles for utilization control |

## Release Checklist (Confluence Copy)
- [ ] Tooling prerequisites validated
- [ ] Backend reachable and lock table healthy
- [ ] Plan reviewed and approved
- [ ] Secret references verified (`saml_xml_secret_arn`, if pool)
- [ ] Apply completed without drift/errors
- [ ] Outputs captured in change record
- [ ] Post-deploy validation completed
