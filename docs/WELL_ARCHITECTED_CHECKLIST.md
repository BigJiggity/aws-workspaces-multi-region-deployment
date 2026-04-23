# AWS Well-Architected Checklist

Use this checklist before production rollout or major changes.

## Operational Excellence
- [ ] `scripts/configure-project.sh` has been run for the target account/regions.
- [ ] `scripts/preflight.sh` passes successfully.
- [ ] Unit-level runbooks are available for impacted stacks.

## Security
- [ ] Backend S3 bucket encryption and TLS-only policy are enabled.
- [ ] S3 public access is blocked.
- [ ] DynamoDB state locking is enabled.
- [ ] Secrets are sourced from Secrets Manager.

## Reliability
- [ ] Regional deployment directories match intended target regions.
- [ ] Terraform remote state keys are unique per unit.
- [ ] Multi-AZ or regional resiliency assumptions are validated.

## Performance Efficiency
- [ ] Resource sizing matches workload requirements.
- [ ] Regional placement aligns with user latency and compliance requirements.

## Cost Optimization
- [ ] WorkSpaces defaults use `AUTO_STOP` unless exception approved.
- [ ] Unused stacks/regions are not deployed.

## Sustainability
- [ ] Idle resource footprint minimized.
- [ ] Reusable modules are used instead of duplicate resource definitions.
