# Project Summary

This repository provides a standalone, configurable Terragrunt/Terraform framework for AWS WorkSpaces multi-region deployments.

## Scope
- Multi-region WorkSpaces deployment units organized with Terragrunt hierarchy.
- Reusable Terraform modules for platform components.
- Backend bootstrap infrastructure (S3, DynamoDB, KMS) for state management.
- Centralized configuration and automation scripts for setup, validation, and operations.

## Configuration Model
- Primary settings are managed through `config/deployment.env`.
- `scripts/configure-project.sh` applies account, region, naming, backend, and WorkSpaces settings.
- `scripts/preflight.sh` validates tooling, credentials, backend access, and expected region structure.

## Operational Model
- Deploy backend first for remote state dependencies.
- Deploy targeted units under `live/aws/...` per stack/account/region.
- Use runbook scripts for common operational workflows.

## Documentation Set
- `README.md`: quickstart and repository layout.
- `docs/PREREQUISITES.md`: required tools and baseline setup.
- `docs/STYLE_GUIDE.md`: implementation and structure standards.
- `docs/WELL_ARCHITECTED_ALIGNMENT.md`: control mapping to AWS Well-Architected pillars.
- `docs/WELL_ARCHITECTED_CHECKLIST.md`: review checklist before production changes.
