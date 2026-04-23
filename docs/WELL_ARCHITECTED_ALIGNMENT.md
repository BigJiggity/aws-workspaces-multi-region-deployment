# AWS Well-Architected Alignment (Merged Template)

This repository maps implementation controls to all six AWS Well-Architected pillars.

## Operational Excellence
- Terragrunt hierarchy enforces predictable deployment boundaries (`live/aws/<stack>/<account>/<region>/...`).
- `scripts/configure-project.sh` provides deterministic configuration updates from a single config file.
- `scripts/preflight.sh` validates tooling, credentials, backend access, and expected region layout before deployment.
- Per-unit Terragrunt state keys isolate changes and simplify rollback.

## Security
- Backend module supports KMS encryption, TLS-only bucket policy, and blocked public access.
- WorkSpaces configurations keep sensitive values in AWS Secrets Manager (SAML metadata secret ARN).
- Sanitized placeholders remove embedded account-specific runtime artifacts from distributed source.
- Standardized tags support asset ownership and compliance controls.

## Reliability
- Remote state locking via DynamoDB is enforced in WorkSpaces Terragrunt units.
- Region-aware unit generation reduces manual drift in multi-region rollout.
- Shared defaults and typed Terraform variables reduce misconfiguration risk.

## Performance Efficiency
- Multi-region support enables workload placement near users and DR strategies.
- WorkSpaces pools and personal tiers are independently deployable for right-sized scaling.

## Cost Optimization
- Default WorkSpaces running mode is `AUTO_STOP`.
- DynamoDB locking uses on-demand billing by default.
- Region selection is explicit and can be pruned with `PRUNE_REGIONS=true`.

## Sustainability
- `AUTO_STOP` and targeted unit deploys reduce idle capacity.
- Reusable modules avoid duplicate infrastructure definitions.

## Recommended Control Additions Before Production
- Add policy-as-code checks (OPA/Conftest, Checkov, tfsec) to CI.
- Add a remote-state bootstrap runbook for multi-account org setups.
- Add automated drift detection and periodic compliance scanning.
