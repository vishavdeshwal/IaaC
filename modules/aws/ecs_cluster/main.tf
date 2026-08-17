resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name

  setting {
    name = "containerInsights"
    # Explicit tier wins when provided; otherwise fall back to the legacy bool
    # so existing callers keep their current behaviour unchanged.
    value = var.container_insights_value != null ? var.container_insights_value : (var.enable_container_insights ? "enabled" : "disabled")
  }

  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
    Project     = var.project
  }
}
