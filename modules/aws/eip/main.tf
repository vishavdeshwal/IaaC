resource "aws_eip" "eip" {
  domain   = "vpc"
  instance = var.instance_id

  tags = {
    Name        = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}"
    Environment = var.environment
    Project     = var.project
  }
}