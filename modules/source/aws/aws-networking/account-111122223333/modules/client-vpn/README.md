# client-vpn

## Overview

- Type: Reusable module
- Path: aws/aws-networking/account-111122223333/modules/client-vpn
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_acm_certificate
- aws_cloudwatch_log_group
- aws_cloudwatch_log_stream
- aws_ec2_client_vpn_authorization_rule
- aws_ec2_client_vpn_endpoint
- aws_ec2_client_vpn_network_association
- aws_ec2_client_vpn_route
- aws_route
- aws_route_table
- aws_route_table_association
- aws_secretsmanager_secret
- aws_secretsmanager_secret_version
- aws_security_group
- aws_subnet
- tls_cert_request
- tls_locally_signed_cert
- tls_private_key
- tls_self_signed_cert

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
