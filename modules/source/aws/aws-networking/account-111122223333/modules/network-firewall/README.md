# network-firewall

## Overview

- Type: Reusable module
- Path: aws/aws-networking/account-111122223333/modules/network-firewall
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_cloudwatch_log_group
- aws_networkfirewall_firewall
- aws_networkfirewall_firewall_policy
- aws_networkfirewall_logging_configuration
- aws_networkfirewall_rule_group

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
