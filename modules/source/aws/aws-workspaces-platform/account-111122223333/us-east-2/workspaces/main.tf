# ==============================================================================
# MODULE: WorkSpaces Instances
# ==============================================================================

locals {
  # Index WorkSpaces by username for deterministic naming.
  workspaces_by_user = { for ws in var.workspaces : ws.user_name => ws }
}

resource "aws_workspaces_workspace" "this" {
  for_each = local.workspaces_by_user

  directory_id = var.directory_id
  user_name    = each.value.user_name
  bundle_id    = each.value.bundle_id

  workspace_properties {
    running_mode                              = var.running_mode
    running_mode_auto_stop_timeout_in_minutes = var.auto_stop_timeout

    # Optional overrides for volume sizes and compute type.
    root_volume_size_gib = var.root_volume_size
    user_volume_size_gib = var.user_volume_size
    compute_type_name    = var.compute_type
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.value.name_suffix}"
  })

  # WorkSpaces can take a long time to reach AVAILABLE.
  timeouts {
    create = var.create_timeout
  }
}
