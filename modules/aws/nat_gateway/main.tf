resource "aws_nat_gateway" "nat" {
  allocation_id = var.availability_mode == "regional" ? null : var.eip_allocation_id
  subnet_id     = var.public_subnet_id

  tags = {
    Name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-nat-gateway"
  }

  lifecycle {
    ignore_changes = [
      allocation_id,
      subnet_id,
      secondary_allocation_ids
    ]
  }

  depends_on = [var.igw_dependency]
}

