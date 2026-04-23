# ecr

## Overview

- Type: Reusable module
- Path: aws/aws-vaultwarden/account-111122223333/us-east-2/modules/ecr
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_ecr_lifecycle_policy
- aws_ecr_repository
- aws_ecr_repository_policy

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
