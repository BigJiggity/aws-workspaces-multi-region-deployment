# ==============================================================================
# ECS CLUSTER AND SERVICE
# ==============================================================================

# ------------------------------------------------------------------------------
# ECS CLUSTER
# ------------------------------------------------------------------------------
resource "aws_ecs_cluster" "vaultwarden" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "vaultwarden" {
  cluster_name = aws_ecs_cluster.vaultwarden.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ------------------------------------------------------------------------------
# TASK DEFINITION
# ------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "vaultwarden" {
  family                   = "${local.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "vaultwarden"
      image     = "${aws_ecr_repository.vaultwarden.repository_url}:${var.container_image_tag}"
      essential = true

      portMappings = concat(
        [
          {
            containerPort = local.container_port
            hostPort      = local.container_port
            protocol      = "tcp"
          }
        ],
        var.enable_websocket ? [
          {
            containerPort = local.websocket_port
            hostPort      = local.websocket_port
            protocol      = "tcp"
          }
        ] : []
      )

      environment = [
        {
          name  = "DOMAIN"
          value = "https://${var.fqdn}"
        },
        {
          name  = "ROCKET_PORT"
          value = tostring(local.container_port)
        },
        {
          name  = "SIGNUPS_ALLOWED"
          value = tostring(var.signups_allowed)
        },
        {
          name  = "INVITATIONS_ALLOWED"
          value = tostring(var.invitations_allowed)
        },
        {
          name  = "SHOW_PASSWORD_HINT"
          value = tostring(var.show_password_hint)
        },
        {
          name  = "WEBSOCKET_ENABLED"
          value = tostring(var.enable_websocket)
        },
        {
          name  = "WEBSOCKET_PORT"
          value = tostring(local.websocket_port)
        },
        {
          name  = "PUSH_ENABLED"
          value = tostring(var.push_enabled)
        },
        {
          name  = "LOG_LEVEL"
          value = var.log_level
        },
        {
          name  = "ENABLE_DB_WAL"
          value = "false" # Not applicable for PostgreSQL
        }
      ]

      secrets = concat(
        [
          {
            name      = "DATABASE_URL"
            valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:url::"
          }
        ],
        var.enable_admin_panel ? [
          {
            name      = "ADMIN_TOKEN"
            valueFrom = aws_secretsmanager_secret.admin_token.arn
          }
        ] : [],
        var.push_enabled ? [
          {
            name      = "PUSH_INSTALLATION_ID"
            valueFrom = "${aws_secretsmanager_secret.push_credentials[0].arn}:installation_id::"
          },
          {
            name      = "PUSH_INSTALLATION_KEY"
            valueFrom = "${aws_secretsmanager_secret.push_credentials[0].arn}:installation_key::"
          }
        ] : [],
        var.smtp_enabled ? [
          {
            name      = "SMTP_HOST"
            valueFrom = "${aws_secretsmanager_secret.smtp_credentials[0].arn}:host::"
          },
          {
            name      = "SMTP_PORT"
            valueFrom = "${aws_secretsmanager_secret.smtp_credentials[0].arn}:port::"
          },
          {
            name      = "SMTP_SECURITY"
            valueFrom = "${aws_secretsmanager_secret.smtp_credentials[0].arn}:security::"
          },
          {
            name      = "SMTP_USERNAME"
            valueFrom = "${aws_secretsmanager_secret.smtp_credentials[0].arn}:username::"
          },
          {
            name      = "SMTP_PASSWORD"
            valueFrom = "${aws_secretsmanager_secret.smtp_credentials[0].arn}:password::"
          },
          {
            name      = "SMTP_FROM"
            valueFrom = "${aws_secretsmanager_secret.smtp_credentials[0].arn}:from::"
          },
          {
            name  = "SMTP_FROM_NAME"
            value = var.smtp_from_name
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "vaultwarden"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${local.container_port}/alive || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-task"
  })
}

# ------------------------------------------------------------------------------
# ECS SERVICE
# ------------------------------------------------------------------------------
resource "aws_ecs_service" "vaultwarden" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.vaultwarden.id
  task_definition = aws_ecs_task_definition.vaultwarden.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.vaultwarden.arn
    container_name   = "vaultwarden"
    container_port   = local.container_port
  }

  dynamic "load_balancer" {
    for_each = var.enable_websocket ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.websocket[0].arn
      container_name   = "vaultwarden"
      container_port   = local.websocket_port
    }
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Allow time for RDS to be ready
  depends_on = [
    aws_db_instance.vaultwarden,
    aws_lb_listener.https
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-service"
  })

  lifecycle {
    ignore_changes = [desired_count] # Allow autoscaling
  }
}

# ------------------------------------------------------------------------------
# AUTO SCALING
# ------------------------------------------------------------------------------
resource "aws_appautoscaling_target" "vaultwarden" {
  max_capacity       = 4
  min_capacity       = var.ecs_desired_count
  resource_id        = "service/${aws_ecs_cluster.vaultwarden.name}/${aws_ecs_service.vaultwarden.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "vaultwarden_cpu" {
  name               = "${local.name_prefix}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.vaultwarden.resource_id
  scalable_dimension = aws_appautoscaling_target.vaultwarden.scalable_dimension
  service_namespace  = aws_appautoscaling_target.vaultwarden.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "vaultwarden_memory" {
  name               = "${local.name_prefix}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.vaultwarden.resource_id
  scalable_dimension = aws_appautoscaling_target.vaultwarden.scalable_dimension
  service_namespace  = aws_appautoscaling_target.vaultwarden.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
