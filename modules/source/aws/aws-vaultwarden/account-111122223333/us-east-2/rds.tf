# ==============================================================================
# RDS POSTGRESQL
# ==============================================================================

# ------------------------------------------------------------------------------
# DATABASE PASSWORD
# ------------------------------------------------------------------------------
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ------------------------------------------------------------------------------
# DB SUBNET GROUP
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "vaultwarden" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Subnet group for VaultWarden RDS"
  subnet_ids  = data.aws_subnets.private.ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# ------------------------------------------------------------------------------
# DB PARAMETER GROUP
# ------------------------------------------------------------------------------
resource "aws_db_parameter_group" "vaultwarden" {
  name        = "${local.name_prefix}-pg16-params"
  family      = "postgres16"
  description = "Parameter group for VaultWarden PostgreSQL 16"

  # TLS enforcement
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Logging
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

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pg16-params"
  })
}

# ------------------------------------------------------------------------------
# KMS KEY FOR RDS ENCRYPTION
# ------------------------------------------------------------------------------
resource "aws_kms_key" "rds" {
  description             = "KMS key for VaultWarden RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ------------------------------------------------------------------------------
# RDS INSTANCE
# ------------------------------------------------------------------------------
resource "aws_db_instance" "vaultwarden" {
  identifier = "${local.name_prefix}-postgres"

  # Engine
  engine               = "postgres"
  engine_version       = "16.4"
  instance_class       = var.db_instance_class
  parameter_group_name = aws_db_parameter_group.vaultwarden.name

  # Storage
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432

  # Network
  db_subnet_group_name   = aws_db_subnet_group.vaultwarden.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  # Backup
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Protection
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${local.name_prefix}-final-snapshot"

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Updates
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres"
  })

  lifecycle {
    prevent_destroy = false # Set to true in production
  }
}

# ------------------------------------------------------------------------------
# RDS ENHANCED MONITORING IAM ROLE
# ------------------------------------------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"

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

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-monitoring-role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
