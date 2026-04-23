# ==============================================================================
# MODULE: WorkSpaces Pool - SOC
# ==============================================================================

# Preflight checks to fail fast on invalid settings.
resource "null_resource" "preflight" {
  triggers = {
    pool_name           = var.pool_name
    pool_directory_id   = var.pool_directory_id
    bundle_id           = var.bundle_id
    vpc_id              = var.vpc_id
    subnet_ids          = join(",", var.subnet_ids)
    saml_xml_secret_arn = var.saml_xml_secret_arn
    min_user_sessions   = tostring(var.min_user_sessions)
    max_user_sessions   = tostring(var.max_user_sessions)
    desired_sessions    = tostring(var.desired_user_sessions)
  }

  lifecycle {
    precondition {
      condition     = can(regex("^wsd-[0-9a-z]{8,63}$", var.pool_directory_id))
      error_message = "pool_directory_id must be a WorkSpaces Pools directory ID (wsd-xxxxxxxx)."
    }
    precondition {
      condition     = can(regex("^wsb-[0-9a-z]{8,63}$", var.bundle_id))
      error_message = "bundle_id must match wsb-xxxxxxxx."
    }
    precondition {
      condition     = var.vpc_id != "" && length(var.subnet_ids) >= 2
      error_message = "vpc_id and at least two subnet_ids are required."
    }
    precondition {
      condition     = can(regex("^arn:aws:secretsmanager:.*:secret:.*", var.saml_xml_secret_arn))
      error_message = "saml_xml_secret_arn must be a valid Secrets Manager secret ARN."
    }
    precondition {
      condition     = var.min_user_sessions <= var.max_user_sessions
      error_message = "min_user_sessions must be <= max_user_sessions."
    }
    precondition {
      condition     = var.desired_user_sessions >= var.min_user_sessions && var.desired_user_sessions <= var.max_user_sessions
      error_message = "desired_user_sessions must be between min_user_sessions and max_user_sessions."
    }
  }
}

locals {
  # Convert timeout inputs from minutes to seconds for WorkSpaces Pools API.
  max_user_duration_seconds       = var.max_user_duration_minutes * 60
  disconnect_timeout_seconds      = var.disconnect_timeout_minutes * 60
  idle_disconnect_timeout_seconds = var.idle_disconnect_timeout_minutes * 60

  # Scaling policy defaults required by the shadbury pooled module.
  scaling_settings = {
    percentage_type     = true
    maximum_capacity    = var.max_user_sessions
    minimum_capacity    = var.min_user_sessions
    increment           = 1
    decrement           = 1
    scale_out_threshold = 80
    scale_in_threshold  = 20
  }
}

# Load SAML metadata XML from Secrets Manager to avoid storing XML in code.
data "aws_secretsmanager_secret_version" "saml_xml" {
  secret_id = var.saml_xml_secret_arn
}

# Use the requested pooled module from the Terraform Registry.
module "workspaces_pooled" {
  source  = "shadbury/workspaces-pooled/aws"
  version = "1.0.3"

  vpc_id       = var.vpc_id
  subnet_ids   = var.subnet_ids
  directory_id = var.pool_directory_id
  saml_xml     = data.aws_secretsmanager_secret_version.saml_xml.secret_string

  workspaces_pooled_settings = {
    bundle_id             = var.bundle_id
    desired_user_sessions = var.desired_user_sessions
    description           = var.pool_description
    pool_name             = var.pool_name
  }

  timeout_settings = {
    disconnect_timeout_in_seconds      = local.disconnect_timeout_seconds
    idle_disconnect_timeout_in_seconds = local.idle_disconnect_timeout_seconds
    max_user_duration_in_seconds       = local.max_user_duration_seconds
  }

  scaling_settings = local.scaling_settings

  depends_on = [null_resource.preflight]
}

# Resolve pool details from the known stack name created by the module.
data "aws_cloudformation_stack" "workspaces_pooled" {
  name = var.pool_name

  depends_on = [module.workspaces_pooled]
}
