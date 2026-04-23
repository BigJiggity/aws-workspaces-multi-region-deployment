# Root Terragrunt configuration shared by all deployable stacks.

locals {
  common_metadata = {
    managed_by = "terragrunt"
    repository = "aws-workspaces-multi-region-deployment"
  }
}

terraform {
  # Automatically include common tfvars files when present in a unit directory.
  extra_arguments "common_var_files" {
    commands = get_terraform_commands_that_need_vars()
    optional_var_files = [
      "${get_terragrunt_dir()}/terraform.tfvars",
      "${get_terragrunt_dir()}/terraform.auto.tfvars",
      "${get_terragrunt_dir()}/common.tfvars"
    ]
  }

  # Forward lock timeout for long-running AWS operations.
  extra_arguments "lock_timeout" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }
}

inputs = {
  common_metadata = local.common_metadata
}
