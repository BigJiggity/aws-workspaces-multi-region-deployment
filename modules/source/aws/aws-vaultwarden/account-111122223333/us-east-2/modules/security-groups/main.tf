# ==============================================================================
# SECURITY GROUPS MODULE - MAIN
# ==============================================================================

# ------------------------------------------------------------------------------
# ALB Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Security group for VaultWarden ALB"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ALB inbound - HTTPS from internet
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-https"
  })
}

# ALB inbound - HTTP redirect
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet (redirect to HTTPS)"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-http"
  })
}

# ALB outbound - To ECS
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To ECS containers"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-to-ecs"
  })
}

# ------------------------------------------------------------------------------
# ECS Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "ecs" {
  name        = "${var.name_prefix}-ecs-sg"
  description = "Security group for VaultWarden ECS tasks"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ECS inbound - From ALB
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "From ALB"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-from-alb"
  })
}

# ECS outbound - To RDS
resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "To RDS"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-to-rds"
  })
}

# ECS outbound - HTTPS to VPC
resource "aws_vpc_security_group_egress_rule" "ecs_https" {
  security_group_id = aws_security_group.ecs.id
  description       = "HTTPS to VPC (AWS services)"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-https-vpc"
  })
}

# ECS outbound - HTTPS to internet
resource "aws_vpc_security_group_egress_rule" "ecs_https_internet" {
  security_group_id = aws_security_group.ecs.id
  description       = "HTTPS to internet (push notifications, HIBP)"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-https-internet"
  })
}

# ECS outbound - SMTP
resource "aws_vpc_security_group_egress_rule" "ecs_smtp" {
  security_group_id = aws_security_group.ecs.id
  description       = "SMTP for email"
  from_port         = 587
  to_port           = 587
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-smtp"
  })
}

# ECS outbound - DNS UDP
resource "aws_vpc_security_group_egress_rule" "ecs_dns_udp" {
  security_group_id = aws_security_group.ecs.id
  description       = "DNS UDP"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = var.vpc_cidr

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-dns-udp"
  })
}

# ECS outbound - DNS TCP
resource "aws_vpc_security_group_egress_rule" "ecs_dns_tcp" {
  security_group_id = aws_security_group.ecs.id
  description       = "DNS TCP"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-dns-tcp"
  })
}

# ------------------------------------------------------------------------------
# RDS Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Security group for VaultWarden RDS"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS inbound - From ECS only
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from ECS"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-from-ecs"
  })
}
