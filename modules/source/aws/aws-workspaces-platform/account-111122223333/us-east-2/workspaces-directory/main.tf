# ==============================================================================
# MODULE: WorkSpaces Directory Registration
# ==============================================================================

# Register the existing Directory (AD Connector or Managed AD) with WorkSpaces.
resource "aws_workspaces_directory" "this" {
  directory_id = var.directory_id
  subnet_ids   = var.directory_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-workspaces-directory"
  })
}

# Security group for WorkSpaces directory registration.
resource "aws_security_group" "workspaces_directory" {
  name_prefix = "${var.name_prefix}-wks-dir-"
  description = "WorkSpaces directory security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-workspaces-directory-sg"
  })
}

# Allow directory access from trusted CIDRs.
resource "aws_security_group_rule" "trusted_ingress" {
  for_each = { for idx, cidr in var.trusted_cidrs : idx => cidr }

  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [each.value.source]
  security_group_id = aws_security_group.workspaces_directory.id
  description       = each.value.description
}

# Allow outbound traffic from the directory security group.
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.workspaces_directory.id
  description       = "Allow all outbound"
}
