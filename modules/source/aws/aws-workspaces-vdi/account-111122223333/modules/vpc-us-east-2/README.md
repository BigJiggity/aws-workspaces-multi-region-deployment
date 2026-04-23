# vpc-us-east-2

## Overview

- Type: Reusable module
- Path: aws/aws-workspaces-vdi/account-111122223333/modules/vpc-us-east-2
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_cloudwatch_log_group
- aws_eip
- aws_flow_log
- aws_iam_role
- aws_iam_role_policy
- aws_internet_gateway
- aws_nat_gateway
- aws_route
- aws_route_table
- aws_route_table_association
- aws_subnet
- aws_vpc

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
