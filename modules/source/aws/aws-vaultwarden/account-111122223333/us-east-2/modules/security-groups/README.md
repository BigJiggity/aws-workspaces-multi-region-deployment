# security-groups

## Overview

- Type: Reusable module
- Path: aws/aws-vaultwarden/account-111122223333/us-east-2/modules/security-groups
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_security_group
- aws_vpc_security_group_egress_rule
- aws_vpc_security_group_ingress_rule

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
