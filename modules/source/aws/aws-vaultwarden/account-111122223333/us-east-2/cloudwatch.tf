# ==============================================================================
# CLOUDWATCH LOGGING AND MONITORING
# ==============================================================================

# ------------------------------------------------------------------------------
# LOG GROUPS
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-logs"
  })
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-waf-logs"
  })
}

# ------------------------------------------------------------------------------
# CLOUDWATCH ALARMS
# ------------------------------------------------------------------------------

# ECS Service - High CPU
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "${local.name_prefix}-ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilization is high"

  dimensions = {
    ClusterName = aws_ecs_cluster.vaultwarden.name
    ServiceName = aws_ecs_service.vaultwarden.name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-high-cpu-alarm"
  })
}

# ECS Service - High Memory
resource "aws_cloudwatch_metric_alarm" "ecs_high_memory" {
  alarm_name          = "${local.name_prefix}-ecs-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS memory utilization is high"

  dimensions = {
    ClusterName = aws_ecs_cluster.vaultwarden.name
    ServiceName = aws_ecs_service.vaultwarden.name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-high-memory-alarm"
  })
}

# ECS Service - Unhealthy Tasks
resource "aws_cloudwatch_metric_alarm" "ecs_unhealthy_tasks" {
  alarm_name          = "${local.name_prefix}-ecs-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "No healthy ECS tasks behind ALB"

  dimensions = {
    TargetGroup  = aws_lb_target_group.vaultwarden.arn_suffix
    LoadBalancer = aws_lb.vaultwarden.arn_suffix
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-unhealthy-alarm"
  })
}

# RDS - High CPU
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "${local.name_prefix}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.vaultwarden.identifier
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-high-cpu-alarm"
  })
}

# RDS - Low Free Storage
resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  alarm_name          = "${local.name_prefix}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240 # 10 GB in bytes
  alarm_description   = "RDS free storage is below 10GB"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.vaultwarden.identifier
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-low-storage-alarm"
  })
}

# RDS - High Connections
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  alarm_name          = "${local.name_prefix}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS connection count is high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.vaultwarden.identifier
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-high-connections-alarm"
  })
}

# ALB - High 5XX Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${local.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB is receiving 5XX errors from targets"

  dimensions = {
    LoadBalancer = aws_lb.vaultwarden.arn_suffix
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-5xx-alarm"
  })
}

# WAF - Blocked Requests
resource "aws_cloudwatch_metric_alarm" "waf_blocked" {
  alarm_name          = "${local.name_prefix}-waf-blocked"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "WAF is blocking a high number of requests"

  dimensions = {
    WebACL = aws_wafv2_web_acl.vaultwarden.name
    Region = var.region
    Rule   = "ALL"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-waf-blocked-alarm"
  })
}

# ------------------------------------------------------------------------------
# CLOUDWATCH DASHBOARD
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "vaultwarden" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS CPU & Memory"
          region = var.region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.vaultwarden.name, "ServiceName", aws_ecs_service.vaultwarden.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "RDS Performance"
          region = var.region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.vaultwarden.identifier],
            [".", "DatabaseConnections", ".", "."],
            [".", "ReadIOPS", ".", "."],
            [".", "WriteIOPS", ".", "."]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count"
          region = var.region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.vaultwarden.arn_suffix],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "WAF Requests"
          region = var.region
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.vaultwarden.name, "Region", var.region, "Rule", "ALL"],
            [".", "BlockedRequests", ".", ".", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "ALB Latency"
          region = var.region
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.vaultwarden.arn_suffix]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "RDS Storage"
          region = var.region
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.vaultwarden.identifier]
          ]
          period = 300
          stat   = "Average"
        }
      }
    ]
  })
}
