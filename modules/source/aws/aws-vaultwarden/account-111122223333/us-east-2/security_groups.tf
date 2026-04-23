# ==============================================================================
# SECURITY GROUPS
# ==============================================================================

# ------------------------------------------------------------------------------
# ALB SECURITY GROUP
# Allows HTTPS from anywhere, egress to ECS tasks
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for VaultWarden ALB"
  vpc_id      = data.aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "https-ingress"
  }
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To ECS tasks"
  ip_protocol                  = "tcp"
  from_port                    = local.container_port
  to_port                      = local.container_port
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name = "to-ecs"
  }
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs_websocket" {
  count = var.enable_websocket ? 1 : 0

  security_group_id            = aws_security_group.alb.id
  description                  = "To ECS tasks (WebSocket)"
  ip_protocol                  = "tcp"
  from_port                    = local.websocket_port
  to_port                      = local.websocket_port
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name = "to-ecs-websocket"
  }
}

# ------------------------------------------------------------------------------
# ECS SECURITY GROUP
# Allows traffic from ALB, egress to RDS and VPC endpoints
# ------------------------------------------------------------------------------
resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Security group for VaultWarden ECS tasks"
  vpc_id      = data.aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "From ALB"
  ip_protocol                  = "tcp"
  from_port                    = local.container_port
  to_port                      = local.container_port
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name = "from-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb_websocket" {
  count = var.enable_websocket ? 1 : 0

  security_group_id            = aws_security_group.ecs.id
  description                  = "From ALB (WebSocket)"
  ip_protocol                  = "tcp"
  from_port                    = local.websocket_port
  to_port                      = local.websocket_port
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name = "from-alb-websocket"
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "To RDS PostgreSQL"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds.id

  tags = {
    Name = "to-rds"
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_https" {
  security_group_id = aws_security_group.ecs.id
  description       = "HTTPS egress (APIs, updates)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "https-egress"
  }
}

# ------------------------------------------------------------------------------
# RDS SECURITY GROUP
# Allows traffic only from ECS tasks
# ------------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for VaultWarden RDS"
  vpc_id      = data.aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "From ECS tasks"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name = "from-ecs"
  }
}
