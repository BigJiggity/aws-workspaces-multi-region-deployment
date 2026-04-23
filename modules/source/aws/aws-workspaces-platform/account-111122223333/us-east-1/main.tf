# ==============================================================================
# ROOT MODULE: WorkSpaces Pilot - us-east-1
# ==============================================================================

# ------------------------------------------------------------------------------
# SUBNET LOOKUP BY CIDR + AZ
# ------------------------------------------------------------------------------
# We use both CIDR and AZ/AZ-ID to ensure the selected subnets are the exact ones
# approved for WorkSpaces, and in supported Availability Zones.

# Preflight checks to fail fast on missing or invalid inputs.
resource "null_resource" "preflight" {
  triggers = {
    directory_id = var.directory_id
    subnet_count = tostring(length(var.workspaces_subnets))
  }

  lifecycle {
    # WorkSpaces directory ID must be set to register in AWS WorkSpaces.
    precondition {
      condition     = var.directory_id != ""
      error_message = "directory_id must be set."
    }
    # Directory name is used for tagging and traceability.
    precondition {
      condition     = var.directory_name != ""
      error_message = "directory_name must be set."
    }
    # WorkSpaces requires two subnets in supported AZs.
    precondition {
      condition     = length(var.workspaces_subnets) >= 2
      error_message = "At least two WorkSpaces subnets must be provided."
    }
    # Security group rules require trusted CIDRs.
    precondition {
      condition     = length(var.trusted_cidrs) > 0
      error_message = "trusted_cidrs must not be empty."
    }
  }
}

data "aws_subnet" "workspaces" {
  for_each = var.workspaces_subnets

  filter {
    name   = "cidr-block"
    values = [each.key]
  }

  filter {
    name   = each.value.az_id != "" ? "availability-zone-id" : "availability-zone"
    values = [each.value.az_id != "" ? each.value.az_id : each.value.az]
  }
}

# Normalize order for determinism.
locals {
  # Normalize subnet order for stable plans and deterministic output.
  ordered_subnet_cidrs = sort(keys(var.workspaces_subnets))
  workspaces_subnet_ids = [
    for cidr in local.ordered_subnet_cidrs : data.aws_subnet.workspaces[cidr].id
  ]
  vpc_ids = distinct([
    for cidr in local.ordered_subnet_cidrs : data.aws_subnet.workspaces[cidr].vpc_id
  ])
  vpc_id = local.vpc_ids[0]

  # Centralized tags passed to all WorkSpaces resources.
  common_tags = var.tags
}

# Lookup VPC details for security group rules.
data "aws_vpc" "selected" {
  id = local.vpc_id
}

# ------------------------------------------------------------------------------
# DIRECTORY REGISTRATION WITH WORKSPACES
# ------------------------------------------------------------------------------
module "workspaces_directory" {
  source = "../modules/workspaces-directory"

  # Directory registration and networking.
  name_prefix  = var.name_prefix
  directory_id = var.directory_id

  vpc_id               = local.vpc_id
  vpc_cidr             = data.aws_vpc.selected.cidr_block
  directory_subnet_ids = local.workspaces_subnet_ids
  subnet_ids           = local.workspaces_subnet_ids
  trusted_cidrs        = var.trusted_cidrs

  tags = merge(local.common_tags, {
    DirectoryName = var.directory_name
  })
}

# ------------------------------------------------------------------------------
# WORKSPACES
# ------------------------------------------------------------------------------
module "workspaces" {
  source = "../modules/workspaces"

  # WorkSpaces fleet configuration.
  name_prefix       = var.name_prefix
  directory_id      = module.workspaces_directory.directory_id
  workspaces        = var.workspaces
  running_mode      = var.workspaces_running_mode
  auto_stop_timeout = var.workspaces_auto_stop_timeout
  root_volume_size  = var.workspaces_root_volume_size
  user_volume_size  = var.workspaces_user_volume_size
  compute_type      = var.workspaces_compute_type
  create_timeout    = var.workspaces_create_timeout

  tags = local.common_tags

  depends_on = [module.workspaces_directory]
}
