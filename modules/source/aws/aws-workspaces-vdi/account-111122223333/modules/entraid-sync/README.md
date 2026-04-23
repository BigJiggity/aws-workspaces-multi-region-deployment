# entraid-sync

## Overview

- Type: Reusable module
- Path: aws/aws-workspaces-vdi/account-111122223333/modules/entraid-sync
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_cloudwatch_event_rule
- aws_cloudwatch_event_target
- aws_cloudwatch_log_group
- aws_iam_role
- aws_iam_role_policy
- aws_lambda_function
- aws_lambda_layer_version
- aws_lambda_permission
- aws_secretsmanager_secret
- aws_secretsmanager_secret_version
- aws_security_group

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
