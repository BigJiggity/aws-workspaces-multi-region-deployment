# Terragrunt deployment unit for: live/aws/aws-workspaces-vdi/account-111122223333/us-east-2
#
# This unit deploys Terraform implementation code from modules/source.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}//modules/source/aws/aws-workspaces-vdi/account-111122223333/us-east-2"
}

locals {
  global_cfg   = read_terragrunt_config(find_in_parent_folders("live/global.hcl"))
  provider_cfg = read_terragrunt_config(find_in_parent_folders("live/aws/provider.hcl"))
  stack_cfg    = read_terragrunt_config(find_in_parent_folders("live/aws/aws-workspaces-vdi/stack.hcl"))

  unit_path     = "live/aws/aws-workspaces-vdi/account-111122223333/us-east-2"
  source_path   = "modules/source/aws/aws-workspaces-vdi/account-111122223333/us-east-2"
  account_scope = "account-111122223333"
  region        = "us-east-2"
}

inputs = {
  deployment_layer = local.global_cfg.locals.deployment_layer
  cloud_provider   = local.provider_cfg.locals.cloud_provider
  stack_name       = local.stack_cfg.locals.stack_name
  account_scope    = local.account_scope
  region           = local.region
  unit_path        = local.unit_path
  source_path      = local.source_path
}
