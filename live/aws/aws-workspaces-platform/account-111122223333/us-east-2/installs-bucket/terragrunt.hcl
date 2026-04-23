# Terragrunt deployment unit for: installs-bucket (us-east-2)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../../../modules/source/aws/aws-workspaces-platform/account-111122223333//us-east-2/installs-bucket"
}

remote_state {
  backend = "s3"

  config = {
    bucket         = local.common_cfg.locals.backend.bucket
    key            = "workspaces/platform/us-east-2/installs-bucket.tfstate"
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

  unit_path     = "live/aws/aws-workspaces-platform/account-111122223333/us-east-2/installs-bucket"
  source_path   = "modules/source/aws/aws-workspaces-platform/account-111122223333/us-east-2/installs-bucket"
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

  name_prefix = local.global_cfg.locals.name_prefix
  tags        = local.global_cfg.locals.tags
}
