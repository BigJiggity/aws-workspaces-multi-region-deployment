# managed-ad

## Overview

- Type: Reusable module
- Path: aws/aws-workspaces-vdi/account-111122223333/modules/managed-ad
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_cloudwatch_log_group
- aws_cloudwatch_log_resource_policy
- aws_directory_service_directory
- aws_directory_service_log_subscription
- aws_secretsmanager_secret
- aws_secretsmanager_secret_version
- aws_security_group
- random_password
- time_sleep

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
