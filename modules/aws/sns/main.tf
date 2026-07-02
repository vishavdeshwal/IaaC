resource "aws_sns_topic" "topic" {
  name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}-sns"

  tags = {
    Name        = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}-sns"
    Environment = var.environment
    Project     = var.project
  }
}
