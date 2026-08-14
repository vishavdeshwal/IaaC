resource "aws_ecs_task_definition" "task" {
  count                    = var.task_definition_arn_override == null ? 1 : 0
  family                   = var.family
  network_mode             = var.network_mode
  requires_compatibilities = var.requires_compatibilities
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = var.container_definitions

  tags = {
    Name        = var.family
    Environment = var.environment
    Project     = var.project
  }

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_service_discovery_service" "discovery" {
  count = var.namespace_id != null ? 1 : 0
  name  = var.service_discovery_name != null ? var.service_discovery_name : var.service_name

  dns_config {
    namespace_id   = var.namespace_id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "service" {
  name                               = var.service_name
  cluster                            = var.cluster_arn
  task_definition                    = var.task_definition_arn_override != null ? var.task_definition_arn_override : aws_ecs_task_definition.task[0].arn
  desired_count                      = var.desired_count
  launch_type                        = var.launch_type
  platform_version                   = var.launch_type == "EC2" ? null : var.platform_version
  scheduling_strategy                = "REPLICA"
  availability_zone_rebalancing      = var.availability_zone_rebalancing
  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
  enable_execute_command             = var.enable_execute_command
  health_check_grace_period_seconds  = var.target_group_arn != null ? var.health_check_grace_period_seconds : null
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [1] : []
    content {
      subnets          = var.subnet_ids
      security_groups  = var.security_group_ids
      assign_public_ip = var.assign_public_ip
    }
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.namespace_id != null ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.discovery[0].arn
    }
  }

  dynamic "deployment_circuit_breaker" {
    for_each = var.enable_circuit_breaker ? [1] : []
    content {
      enable   = true
      rollback = true
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_providers
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = lookup(capacity_provider_strategy.value, "base", 0)
    }
  }

  tags = {
    Name        = var.service_name
    Environment = var.environment
    Project     = var.project
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
