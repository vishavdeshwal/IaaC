resource "aws_secretsmanager_secret" "secret" {
  name                    = var.secret_name
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge({
    Name        = var.secret_name
    Environment = var.environment
    Project     = var.project
  }, var.tags)
}

resource "aws_secretsmanager_secret_version" "version" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = var.secret_string

  lifecycle {
    ignore_changes = [secret_string]
  }
}

