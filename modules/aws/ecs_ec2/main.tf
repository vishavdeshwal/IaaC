# -------
# ECS Cluster
# -------

resource "aws_ecs_cluster" "ec2" {
  name = "${var.environment}-${var.project}-${var.cluster_name}"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name        = "${var.environment}-${var.project}-${var.cluster_name}"
    Environment = var.environment
    Project     = var.project
  }
}


# -------
# IAM — Task Execution Role
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
# IAM — Task Role
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
# IAM — EC2 Instance Profile (for ECS container instances)
# Attach this profile to the EC2/ASG instances that join the cluster
# -------

resource "aws_iam_role" "instance" {
  name = "${var.environment}-${var.project}-${var.cluster_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.environment}-${var.project}-${var.cluster_name}-instance-role"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_iam_role_policy_attachment" "instance" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.environment}-${var.project}-${var.cluster_name}-instance-profile"
  role = aws_iam_role.instance.name

  tags = {
    Name        = "${var.environment}-${var.project}-${var.cluster_name}-instance-profile"
    Environment = var.environment
    Project     = var.project
  }
}


# -------
# Task Definition
# -------

resource "aws_ecs_task_definition" "ec2" {
  family                   = "${var.environment}-${var.project}-${var.task_family}"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
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

resource "aws_ecs_service" "ec2" {
  name            = "${var.environment}-${var.project}-${var.service_name}"
  cluster         = aws_ecs_cluster.ec2.id
  task_definition = aws_ecs_task_definition.ec2.arn
  desired_count   = var.desired_count
  launch_type     = "EC2"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = var.security_group_ids
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = {
    Name        = "${var.environment}-${var.project}-${var.service_name}"
    Environment = var.environment
    Project     = var.project
  }
}
