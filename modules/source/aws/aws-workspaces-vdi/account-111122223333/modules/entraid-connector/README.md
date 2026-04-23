# entraid-connector

## Overview

- Type: Reusable module
- Path: aws/aws-workspaces-vdi/account-111122223333/modules/entraid-connector
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_cloudwatch_log_group
- aws_iam_instance_profile
- aws_iam_role
- aws_iam_role_policy
- aws_iam_role_policy_attachment
- aws_instance
- aws_key_pair
- aws_kms_alias
- aws_kms_key
- aws_s3_bucket
- aws_s3_bucket_lifecycle_configuration
- aws_s3_bucket_public_access_block
- aws_s3_bucket_server_side_encryption_configuration
- aws_s3_bucket_versioning
- aws_secretsmanager_secret
- aws_secretsmanager_secret_version
- aws_security_group
- aws_ssm_association
- aws_ssm_document
- tls_private_key

## How to use

1. Reference this module from a Terraform root stack using a module block.
2. Pass required input variables from the calling stack.
3. Consume outputs in parent stacks as needed.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
