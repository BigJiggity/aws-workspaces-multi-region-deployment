# ==============================================================================
# SECRETS MANAGER
# ==============================================================================

# ------------------------------------------------------------------------------
# KMS KEY FOR SECRETS
# ------------------------------------------------------------------------------
resource "aws_kms_key" "secrets" {
  description             = "KMS key for VaultWarden secrets"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-secrets-kms"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${local.name_prefix}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# ------------------------------------------------------------------------------
# ADMIN TOKEN
# Used to access the /admin panel
# ------------------------------------------------------------------------------
resource "random_password" "admin_token" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "admin_token" {
  name        = "${local.name_prefix}/admin-token"
  description = "VaultWarden admin panel token"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-admin-token"
  })
}

resource "aws_secretsmanager_secret_version" "admin_token" {
  secret_id     = aws_secretsmanager_secret.admin_token.id
  secret_string = random_password.admin_token.result
}

# ------------------------------------------------------------------------------
# DATABASE CREDENTIALS
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.name_prefix}/db-credentials"
  description = "VaultWarden RDS PostgreSQL credentials"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.vaultwarden.address
    port     = aws_db_instance.vaultwarden.port
    database = var.db_name
    url      = local.database_url
  })
}

# ------------------------------------------------------------------------------
# PUSH NOTIFICATION CREDENTIALS (Optional)
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "push_credentials" {
  count = var.push_enabled ? 1 : 0

  name        = "${local.name_prefix}/push-credentials"
  description = "Bitwarden push notification credentials"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-push-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "push_credentials" {
  count = var.push_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.push_credentials[0].id
  secret_string = jsonencode({
    installation_id  = var.push_installation_id
    installation_key = var.push_installation_key
  })
}

# ------------------------------------------------------------------------------
# SMTP CREDENTIALS (Optional)
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "smtp_credentials" {
  count = var.smtp_enabled ? 1 : 0

  name        = "${local.name_prefix}/smtp-credentials"
  description = "VaultWarden SMTP credentials"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-smtp-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "smtp_credentials" {
  count = var.smtp_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.smtp_credentials[0].id
  secret_string = jsonencode({
    host     = var.smtp_host
    port     = var.smtp_port
    security = var.smtp_security
    username = var.smtp_username
    password = var.smtp_password
    from     = var.smtp_from
  })
}
