# ==============================================================================
# RDS MODULE - MAIN
# ==============================================================================

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = var.db_password_secret_arn
}

# ------------------------------------------------------------------------------
# DB Subnet Group
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-db-subnet-group"
  description = "Database subnet group for VaultWarden"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# ------------------------------------------------------------------------------
# DB Parameter Group
# ------------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  name        = "${var.name_prefix}-db-params"
  family      = "postgres16"
  description = "Database parameter group for VaultWarden"

  # Force SSL connections
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Logging parameters
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# KMS Key for RDS Encryption
# ------------------------------------------------------------------------------
resource "aws_kms_key" "rds" {
  description             = "KMS key for VaultWarden RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ------------------------------------------------------------------------------
# RDS Instance
# ------------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-db"

  # Engine
  engine               = "postgres"
  engine_version       = "16.4"
  instance_class       = var.instance_class
  parameter_group_name = aws_db_parameter_group.main.name

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = aws_kms_key.rds.arn

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
  port     = 5432

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  # Backup
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  # Monitoring
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  # Security
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.name_prefix}-db-final-snapshot"
  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db"
  })

  lifecycle {
    ignore_changes = [password]
  }
}

# ------------------------------------------------------------------------------
# Enhanced Monitoring IAM Role
# ------------------------------------------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
