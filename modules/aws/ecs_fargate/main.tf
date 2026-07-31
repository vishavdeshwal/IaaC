
# -------
# IAM — Task Execution Role (pulls images, writes logs)
# -------

resource "aws_iam_role" "execution" {
  name = "${var.environment}-${var.project}-${var.task_family}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.environment}-${var.project}-${var.task_family}-exec-role"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# -------
# IAM — Task Role (runtime permissions for containers)
# -------

resource "aws_iam_role" "task" {
  name = "${var.environment}-${var.project}-${var.task_family}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.environment}-${var.project}-${var.task_family}-task-role"
    Environment = var.environment
    Project     = var.project
  }
}


# -------
# Task Definition
# -------

resource "aws_ecs_task_definition" "fargate" {
  family                   = "${var.environment}-${var.project}-${var.task_family}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions    = var.container_definitions

  tags = {
    Name        = "${var.environment}-${var.project}-${var.task_family}"
    Environment = var.environment
    Project     = var.project
  }
}


# -------
# ECS Service
# -------

resource "aws_ecs_service" "fargate" {
  name            = "${var.environment}-${var.project}-${var.service_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.fargate.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  # Ignore task definition changes during deployments (common CI/CD pattern)
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name        = "${var.environment}-${var.project}-${var.service_name}"
    Environment = var.environment
    Project     = var.project
  }
}
