# iam

## Overview

- Type: Reusable module
- Path: aws/aws-vaultwarden/account-111122223333/us-east-2/modules/iam
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_iam_role
- aws_iam_role_policy
- aws_iam_role_policy_attachment

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
