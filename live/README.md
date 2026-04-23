# Live Deployments

This directory contains deployable Terragrunt units and supporting hierarchy metadata.

- live/global.hcl: live-wide metadata.
- live/aws/provider.hcl: provider-level metadata.
- live/aws/<stack>/stack.hcl: stack-level metadata.
- live/aws/<stack>/<account>/account.hcl: account-level metadata.
- live/aws/.../terragrunt.hcl: deployable units.

Run Terragrunt from unit directories containing terragrunt.hcl.
