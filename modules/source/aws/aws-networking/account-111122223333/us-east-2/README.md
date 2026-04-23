# us-east-2

## Overview

- Type: Root stack
- Path: aws/aws-networking/account-111122223333/us-east-2
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_ec2_transit_gateway_peering_attachment_accepter
- aws_ec2_transit_gateway_route
- aws_route

## How to use

1. Ensure required AWS credentials and environment variables are set.
2. From this directory, run terragrunt init.
3. Run terragrunt plan and review the execution plan.
4. Run terragrunt apply to deploy changes.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
