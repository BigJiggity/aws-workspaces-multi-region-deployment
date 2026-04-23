# ==============================================================================
# ECS MODULE - MAIN
# ==============================================================================

# ------------------------------------------------------------------------------
# CloudWatch Log Group
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ------------------------------------------------------------------------------
# ECS Cluster
# ------------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ------------------------------------------------------------------------------
# ECS Task Definition
# ------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        # Domain configuration
        {
          name  = "DOMAIN"
          value = var.vaultwarden_config.domain
        },
        # Security settings
        {
          name  = "SIGNUPS_ALLOWED"
          value = tostring(var.vaultwarden_config.signups_allowed)
        },
        {
          name  = "INVITATIONS_ALLOWED"
          value = tostring(var.vaultwarden_config.invitations_allowed)
        },
        {
          name  = "SHOW_PASSWORD_HINT"
          value = tostring(var.vaultwarden_config.show_password_hint)
        },
        # Features
        {
          name  = "WEBSOCKET_ENABLED"
          value = tostring(var.vaultwarden_config.websocket_enabled)
        },
        {
          name  = "PUSH_ENABLED"
          value = tostring(var.vaultwarden_config.push_enabled)
        },
        # Database
        {
          name  = "DATABASE_URL"
          value = "postgresql://${var.db_username}:PLACEHOLDER@${var.db_host}:${var.db_port}/${var.db_name}"
        },
        # Logging
        {
          name  = "LOG_LEVEL"
          value = var.vaultwarden_config.log_level
        },
        {
          name  = "EXTENDED_LOGGING"
          value = "true"
        },
        # SMTP (if configured)
        {
          name  = "SMTP_HOST"
          value = var.vaultwarden_config.smtp_host
        },
        {
          name  = "SMTP_PORT"
          value = tostring(var.vaultwarden_config.smtp_port)
        },
        {
          name  = "SMTP_SECURITY"
          value = var.vaultwarden_config.smtp_security
        },
        {
          name  = "SMTP_FROM"
          value = var.vaultwarden_config.smtp_from
        },
        # Rocket (web server) settings
        {
          name  = "ROCKET_PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "ROCKET_ADDRESS"
          value = "0.0.0.0"
        },
      ]

      secrets = concat(
        # Database password
        [
          {
            name      = "DATABASE_URL"
            valueFrom = "${var.secrets_config.db_password_arn}:password::"
          }
        ],
        # Admin token (if enabled)
        var.vaultwarden_config.admin_panel_enabled && var.secrets_config.admin_token_arn != "" ? [
          {
            name      = "ADMIN_TOKEN"
            valueFrom = var.secrets_config.admin_token_arn
          }
        ] : [],
        # Push notifications (if enabled)
        var.vaultwarden_config.push_enabled && var.secrets_config.push_id_arn != "" ? [
          {
            name      = "PUSH_INSTALLATION_ID"
            valueFrom = var.secrets_config.push_id_arn
          },
          {
            name      = "PUSH_INSTALLATION_KEY"
            valueFrom = var.secrets_config.push_key_arn
          }
        ] : [],
        # SMTP credentials (if configured)
        var.secrets_config.smtp_username_arn != "" ? [
          {
            name      = "SMTP_USERNAME"
            valueFrom = var.secrets_config.smtp_username_arn
          },
          {
            name      = "SMTP_PASSWORD"
            valueFrom = var.secrets_config.smtp_password_arn
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/alive || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = var.tags
}

# ------------------------------------------------------------------------------
# ECS Service
# ------------------------------------------------------------------------------
resource "aws_ecs_service" "main" {
  name                               = "${var.name_prefix}-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.main.arn
  desired_count                      = var.desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 120

  network_configuration {
    security_groups  = [var.security_group_id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-service"
  })
}

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_region" "current" {}
