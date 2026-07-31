resource "aws_security_group" "security_group" {
  name        = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}-sg"
  description = var.description != null ? var.description : "Security group for ${var.name}"
  vpc_id      = var.vpc_id


  # ----Ingress Rules

  dynamic "ingress" {
    for_each = var.ingress_rules

    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = ingress.value.cidr_blocks
      security_groups = ingress.value.security_groups
      description     = ingress.value.description
    }
  }


  # ----Egress Rules

  dynamic "egress" {
    for_each = var.egress_rules

    content {
      from_port       = egress.value.from_port
      to_port         = egress.value.to_port
      protocol        = egress.value.protocol
      cidr_blocks     = egress.value.cidr_blocks
      security_groups = egress.value.security_groups
      description     = egress.value.description
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}-sg"
  }
}