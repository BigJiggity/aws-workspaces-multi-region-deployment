# account-111122223333

## Overview

- Type: Root stack
- Path: aws/aws-ActiveDirectory/account-111122223333
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_iam_instance_profile
- aws_iam_role
- aws_iam_role_policy_attachment
- aws_instance
- aws_key_pair
- aws_ram_resource_association
- aws_ram_resource_share
- aws_route53_record
- aws_route53_resolver_endpoint
- aws_route53_resolver_rule
- aws_route53_resolver_rule_association
- aws_route53_zone
- aws_route53_zone_association
- aws_secretsmanager_secret
- aws_secretsmanager_secret_version
- aws_security_group
- aws_vpc_security_group_egress_rule
- aws_vpc_security_group_ingress_rule
- tls_private_key

## How to use

1. Ensure required AWS credentials and environment variables are set.
2. From this directory, run terragrunt init.
3. Run terragrunt plan and review the execution plan.
4. Run terragrunt apply to deploy changes.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
