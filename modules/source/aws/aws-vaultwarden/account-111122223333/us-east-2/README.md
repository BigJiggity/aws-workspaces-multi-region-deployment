# us-east-2

## Overview

- Type: Root stack
- Path: aws/aws-vaultwarden/account-111122223333/us-east-2
- Purpose: Manages AWS infrastructure components defined in this directory.

## Resources managed

- aws_acm_certificate
- aws_appautoscaling_policy
- aws_appautoscaling_target
- aws_cloudwatch_dashboard
- aws_cloudwatch_log_group
- aws_cloudwatch_metric_alarm
- aws_db_instance
- aws_db_parameter_group
- aws_db_subnet_group
- aws_ecr_lifecycle_policy
- aws_ecr_pull_through_cache_rule
- aws_ecr_repository
- aws_ecs_cluster
- aws_ecs_cluster_capacity_providers
- aws_ecs_service
- aws_ecs_task_definition
- aws_iam_role
- aws_iam_role_policy
- aws_iam_role_policy_attachment
- aws_kms_alias
- aws_kms_key
- aws_lb
- aws_lb_listener
- aws_lb_listener_rule
- aws_lb_target_group
- aws_s3_bucket
- aws_s3_bucket_lifecycle_configuration
- aws_s3_bucket_policy
- aws_s3_bucket_public_access_block
- aws_s3_bucket_server_side_encryption_configuration
- aws_secretsmanager_secret
- aws_secretsmanager_secret_version
- aws_security_group
- aws_vpc_security_group_egress_rule
- aws_vpc_security_group_ingress_rule
- aws_wafv2_web_acl
- aws_wafv2_web_acl_association
- aws_wafv2_web_acl_logging_configuration
- null_resource
- random_password

## How to use

1. Ensure required AWS credentials and environment variables are set.
2. From this directory, run terragrunt init.
3. Run terragrunt plan and review the execution plan.
4. Run terragrunt apply to deploy changes.

## Notes

- This documentation is sanitized and uses generic placeholders where needed.
- Update variable values and backend/provider settings for your target environment.
