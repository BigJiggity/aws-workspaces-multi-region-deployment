# workspaces

## Overview

- Type: Reusable module
- Path: aws/aws-workspaces-vdi/account-111122223333/modules/workspaces
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_cloudwatch_metric_alarm
- aws_kms_alias
- aws_kms_key
- aws_workspaces_workspace

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
