# tgw-peering

## Overview

- Type: Reusable module
- Path: aws/aws-networking/account-111122223333/modules/tgw-peering
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_ec2_transit_gateway_peering_attachment
- aws_ec2_transit_gateway_route

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
