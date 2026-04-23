# Terragrunt deployment unit for: WorkSpaces SOC pool (us-east-2)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../../../modules/source/aws/aws-workspaces-platform/account-111122223333//us-east-2/workspaces-pool-soc"
}

remote_state {
  backend = "s3"

  config = {
    bucket         = local.common_cfg.locals.backend.bucket
    key            = "workspaces/platform/us-east-2/soc-pool.tfstate"
    region         = local.common_cfg.locals.backend.region
    dynamodb_table = local.common_cfg.locals.backend.dynamodb_table
    encrypt        = true
    kms_key_id     = local.common_cfg.locals.backend.kms_key_id
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

locals {
  global_cfg   = read_terragrunt_config(find_in_parent_folders("live/global.hcl"))
  provider_cfg = read_terragrunt_config(find_in_parent_folders("live/aws/provider.hcl"))
  stack_cfg    = read_terragrunt_config(find_in_parent_folders("live/aws/aws-workspaces-platform/stack.hcl"))
  common_cfg   = read_terragrunt_config(find_in_parent_folders("live/aws/aws-workspaces-platform/account-111122223333/us-east-2/common.hcl"))

  unit_path     = "live/aws/aws-workspaces-platform/account-111122223333/us-east-2/soc-pool"
  source_path   = "modules/source/aws/aws-workspaces-platform/account-111122223333/us-east-2/workspaces-pool-soc"
  account_scope = local.common_cfg.locals.account_scope
  region        = local.common_cfg.locals.region
}

inputs = {
  deployment_layer = local.global_cfg.locals.deployment_layer
  cloud_provider   = local.provider_cfg.locals.cloud_provider
  stack_name       = local.stack_cfg.locals.stack_name
  account_scope    = local.account_scope
  region           = local.region
  unit_path        = local.unit_path
  source_path      = local.source_path

  name_prefix      = local.global_cfg.locals.name_prefix
  pool_name        = "example-workspaces-platform-dev-soc-pool-v1"
  pool_description = "SOC WorkSpaces pool"

  vpc_id = "vpc-00000000000000000"
  subnet_ids = [
    "subnet-00000000000000000",
    "subnet-00000000000000001",  ]

  pool_directory_id   = local.common_cfg.locals.pool_directory_id
  saml_xml_secret_arn = "arn:aws:secretsmanager:us-east-2:111122223333:secret:REPLACE_WITH_SAML_XML_SECRET"

  bundle_id = local.common_cfg.locals.default_bundles.soc

  desired_user_sessions = 2
  min_user_sessions     = 2
  max_user_sessions     = 10

  max_user_duration_minutes       = 480
  disconnect_timeout_minutes      = 60
  idle_disconnect_timeout_minutes = 30

  application_settings_status = "ENABLED"
  application_settings_group  = "example-workspaces-platform-dev/soc-pool-v1"

  running_mode = local.common_cfg.locals.workspaces_running_mode

  tags = merge(local.global_cfg.locals.tags, {
    Application   = "workspaces-pool"
    Purpose       = "SOC Pool Sessions"
    WorkspaceType = "SOC"
  })
}
