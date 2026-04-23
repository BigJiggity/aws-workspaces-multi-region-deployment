# ==============================================================================
# SECRETS MODULE - MAIN
# ==============================================================================

# Generate random password for database
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Generate random admin token
resource "random_password" "admin_token" {
  count   = var.admin_token_enabled ? 1 : 0
  length  = 64
  special = false
}

# Database password secret
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.name_prefix}-db-password"
  description             = "VaultWarden database password"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# Admin token secret
resource "aws_secretsmanager_secret" "admin_token" {
  count                   = var.admin_token_enabled ? 1 : 0
  name                    = "${var.name_prefix}-admin-token"
  description             = "VaultWarden admin panel token"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "admin_token" {
  count         = var.admin_token_enabled ? 1 : 0
  secret_id     = aws_secretsmanager_secret.admin_token[0].id
  secret_string = random_password.admin_token[0].result
}

# Push installation ID secret (if provided)
resource "aws_secretsmanager_secret" "push_installation_id" {
  count                   = var.push_installation_id != "" ? 1 : 0
  name                    = "${var.name_prefix}-push-installation-id"
  description             = "VaultWarden push notification installation ID"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "push_installation_id" {
  count         = var.push_installation_id != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.push_installation_id[0].id
  secret_string = var.push_installation_id
}

# Push installation key secret (if provided)
resource "aws_secretsmanager_secret" "push_installation_key" {
  count                   = var.push_installation_key != "" ? 1 : 0
  name                    = "${var.name_prefix}-push-installation-key"
  description             = "VaultWarden push notification installation key"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "push_installation_key" {
  count         = var.push_installation_key != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.push_installation_key[0].id
  secret_string = var.push_installation_key
}

# SMTP username secret (if provided)
resource "aws_secretsmanager_secret" "smtp_username" {
  count                   = var.smtp_username != "" ? 1 : 0
  name                    = "${var.name_prefix}-smtp-username"
  description             = "VaultWarden SMTP username"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "smtp_username" {
  count         = var.smtp_username != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.smtp_username[0].id
  secret_string = var.smtp_username
}

# SMTP password secret (if provided)
resource "aws_secretsmanager_secret" "smtp_password" {
  count                   = var.smtp_password != "" ? 1 : 0
  name                    = "${var.name_prefix}-smtp-password"
  description             = "VaultWarden SMTP password"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "smtp_password" {
  count         = var.smtp_password != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.smtp_password[0].id
  secret_string = var.smtp_password
}
