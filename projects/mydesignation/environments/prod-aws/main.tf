terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "mydesignation-prod-tfstate-ap-south-1"
    key          = "mydesignation/prod/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
    profile      = "mydsn"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_elb_service_account" "main" {}

locals {
  app_secret_keys = [
    "NODE_ENV",
    "LOG_LEVEL",
    "QUEUE",
    "DATABASE_URL",
    "REDIS_URL",
    "JWT_SECRET",
    "CACHE_ADMIN_TOKEN",
    "SHOPIFY_STORE_DOMAIN",
    "SHOPIFY_API_VERSION",
    "SHOPIFY_ADMIN_TOKEN",
    "SHOPIFY_STOREFRONT_TOKEN",
    "SHOPIFY_WEBHOOK_SECRET",
    "RAZORPAY_KEY_ID",
    "RAZORPAY_KEY_SECRET",
    "LOGISY_API_KEY",
    "CLICKPOST_WEBHOOK_TOKEN",
    "MSG91_AUTH_KEY",
    "MSG91_OTP_TEMPLATE_ID",
    "MSG91_EMAIL_TEMPLATE_ID",
    "SERVICEBUS_QUEUE_NAME",
    "SERVICEBUS_LISTEN_CONNECTION_STRING",
  ]

  app_secrets = [
    for k in local.app_secret_keys : {
      name      = k
      valueFrom = "${module.secrets_manager.secret_arn}:${k}::"
    }
  ]

  app_image = "${module.ecr.repository_url}:${var.image_tag}"
  alb_routable_private_subnet_ids = [
    for idx in range(length(var.public_subnets)) :
    module.subnets.private_subnet_ids["priv-${idx}"]
  ]
}

// =============================================================
// 1. Network (VPC, Subnets, IGW, NAT Gateway)
// =============================================================

module "vpc" {
  source               = "../../../../modules/aws/vpc"
  vpc_cidr             = var.vpc_cidr
  environment          = var.environment
  project              = var.project
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

module "igw" {
  source      = "../../../../modules/aws/igw"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
}

module "subnets" {
  source = "../../../../modules/aws/subnets"
  vpc_id = module.vpc.vpc_id

  public_subnets = {
    for idx, cidr in var.public_subnets : "pub-${idx}" => {
      cidr     = cidr
      az_index = idx
    }
  }

  private_subnets = {
    for idx, cidr in var.private_subnets : "priv-${idx}" => {
      cidr     = cidr
      az_index = idx
    }
  }

  environment = var.environment
  project     = var.project
}

module "nat_eip" {
  source      = "../../../../modules/aws/eip"
  name        = "nat-eip"
  environment = var.environment
  project     = var.project
}

module "nat_gateway" {
  source            = "../../../../modules/aws/nat_gateway"
  eip_allocation_id = module.nat_eip.eip_allocation_id
  public_subnet_id  = values(module.subnets.public_subnet_ids)[0]
  igw_dependency    = module.igw.igw_id
  environment       = var.environment
  project           = var.project
}

module "route_tables" {
  source             = "../../../../modules/aws/route_tables"
  vpc_id             = module.vpc.vpc_id
  igw_id             = module.igw.igw_id
  nat_gateway_id     = module.nat_gateway.nat_gateway_id
  public_subnet_ids  = module.subnets.public_subnet_ids
  private_subnet_ids = module.subnets.private_subnet_ids
  environment        = var.environment
  project            = var.project
}

// =============================================================
// 2. Security Groups
// =============================================================

module "sg_bastion" {
  source      = "../../../../modules/aws/security_groups"
  name        = "bastion"
  description = "Security group for Bastion Host"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from internet"
    }
  ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]
}

module "sg_alb" {
  source      = "../../../../modules/aws/security_groups"
  name        = "alb"
  description = "Security group for Public ALB"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS from internet"
    }
  ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]
}

module "sg_ecs" {
  source      = "../../../../modules/aws/security_groups"
  name        = "ecs"
  description = "Security group for ECS Fargate Tasks"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 3001
      to_port         = 3001
      protocol        = "tcp"
      security_groups = [module.sg_alb.security_group_id]
      description     = "Allow API traffic from ALB"
    }
  ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]
}

module "sg_db" {
  source      = "../../../../modules/aws/security_groups"
  name        = "db"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.sg_bastion.security_group_id, module.sg_ecs.security_group_id]
      description     = "Allow PG traffic from Bastion and ECS"
    }
  ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]
}

module "sg_redis" {
  source      = "../../../../modules/aws/security_groups"
  name        = "redis"
  description = "Security group for ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [module.sg_ecs.security_group_id]
      description     = "Allow Redis traffic from ECS"
    }
  ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]
}

// =============================================================
// 3. Compute (Bastion & ECS Fargate)
// =============================================================

module "iam_role_bastion" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.project}-${var.environment}-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  environment = var.environment
  project     = var.project
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project}-${var.environment}-bastion-profile"
  role = module.iam_role_bastion.role_name
}

module "bastion" {
  source               = "../../../../modules/aws/ec2"
  name                 = "bastion"
  ami_id               = "ami-0a0f1259dd1c90938"
  instance_type        = "t3.micro"
  subnet_id            = values(module.subnets.public_subnet_ids)[0]
  associate_public_ip  = true
  security_group_ids   = [module.sg_bastion.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.bastion.name
  environment          = var.environment
  project              = var.project
}

// =============================================================
// Load Balancing
// =============================================================

module "tg_api" {
  source      = "../../../../modules/aws/target_group"
  name        = "api-v3"
  port        = 3001
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check_path = "/health"
  environment       = var.environment
  project           = var.project
}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project}-${var.environment}-alb-logs-ap-south-1"
  force_destroy = true

  tags = {
    Environment = var.environment
    Project     = var.project
    Purpose     = "ALB Access Logs"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

module "alb" {
  source             = "../../../../modules/aws/alb"
  name               = "app"
  internal           = false
  security_group_ids = [module.sg_alb.security_group_id]
  subnet_ids         = values(module.subnets.public_subnet_ids)

  certificate_arn        = "arn:aws:acm:ap-south-1:658132201265:certificate/47fc48e6-c9e5-4b27-890a-7939256f97bb"
  https_target_group_arn = module.tg_api.target_group_arn

  access_logs_bucket = aws_s3_bucket.alb_logs.id

  environment = var.environment
  project     = var.project

  depends_on = [aws_s3_bucket_policy.alb_logs]
}


// =============================================================
// ECS Fargate (API & Worker)
// =============================================================

module "ecs_cluster" {
  source       = "../../../../modules/aws/ecs_cluster"
  cluster_name = "${var.project}-${var.environment}-app"
  environment  = var.environment
  project      = var.project
}

module "ecs_fargate_api" {
  source             = "../../../../modules/aws/ecs_fargate"
  service_name       = "api"
  cluster_id         = module.ecs_cluster.cluster_id
  task_family        = "api-task"
  subnet_ids         = local.alb_routable_private_subnet_ids
  security_group_ids = [module.sg_ecs.security_group_id]

  target_group_arn = module.tg_api.target_group_arn
  container_name   = "api"
  container_port   = 3001

  # App logs "listening" ~10s after start; 60s leaves headroom without
  # masking a genuinely broken build for long.
  health_check_grace_period_seconds = 60

  environment = var.environment
  project     = var.project

  cpu    = 512
  memory = 1024
  container_definitions = jsonencode([
    {
      name      = "api"
      image     = local.app_image
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
        {
          containerPort = 3001
        }
      ]
      environment = [
        {
          name  = "PORT"
          value = "3001"
        }
      ]
      secrets = local.app_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-api"
          "awslogs-region"        = "ap-south-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

module "ecs_fargate_worker" {
  source             = "../../../../modules/aws/ecs_fargate"
  service_name       = "worker"
  cluster_id         = module.ecs_cluster.cluster_id
  task_family        = "worker-task"
  subnet_ids         = values(module.subnets.private_subnet_ids)
  security_group_ids = [module.sg_ecs.security_group_id]

  environment = var.environment
  project     = var.project

  cpu    = 512
  memory = 1024
  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = local.app_image
      cpu       = 512
      memory    = 1024
      essential = true
      environment = [
        {
          name  = "PORT"
          value = "3001"
        }
      ]
      secrets = local.app_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-worker"
          "awslogs-region"        = "ap-south-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

// =============================================================
// 4. Database & Cache
// =============================================================

module "rds" {
  source              = "../../../../modules/aws/rds"
  identifier          = "pg"
  engine              = "postgres"
  engine_version      = "15.17"
  instance_class      = "db.t3.medium"
  allocated_storage   = 128
  username            = var.db_admin_username
  password            = var.db_admin_password
  security_group_ids  = [module.sg_db.security_group_id]
  subnet_ids          = values(module.subnets.private_subnet_ids)
  publicly_accessible = false
  skip_final_snapshot = true
  environment         = var.environment
  project             = var.project
}

module "elasticache" {
  source             = "../../../../modules/aws/elasticache"
  name               = "redis"
  engine             = "redis"
  node_type          = "cache.t3.medium"
  num_cache_nodes    = 1
  security_group_ids = [module.sg_redis.security_group_id]
  subnet_ids         = values(module.subnets.private_subnet_ids)
  environment        = var.environment
  project            = var.project
}

// =============================================================
// 5. Messaging & Queues
// =============================================================

module "sqs_dlq" {
  source      = "../../../../modules/aws/sqs"
  name        = "dlq"
  environment = var.environment
  project     = var.project
}

module "sqs_main" {
  source            = "../../../../modules/aws/sqs"
  name              = "queue"
  environment       = var.environment
  project           = var.project
  dlq_arn           = module.sqs_dlq.queue_arn
  max_receive_count = 5
}

// =============================================================
// 6. ECR & Storage
// =============================================================

module "ecr" {
  source      = "../../../../modules/aws/ecr"
  name        = "backend"
  environment = var.environment
  project     = var.project
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "${var.project}-${var.environment}-app-bucket-ap-south-1"

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_s3_bucket_cors_configuration" "app_bucket_cors" {
  bucket = aws_s3_bucket.app_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["http://${module.alb.alb_dns_name}"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

// =============================================================
// 7. Secrets Manager
// =============================================================

module "secrets_manager" {
  source      = "../../../../modules/aws/secrets_manager"
  secret_name = "${var.project}-${var.environment}-secrets"
  environment = var.environment
  project     = var.project
}

// =============================================================
// 8. Application IAM Task Permissions
// =============================================================

resource "aws_iam_role_policy" "api_task_sqs" {
  name = "api-sqs-publish"
  role = module.ecs_fargate_api.task_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = [module.sqs_main.queue_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_task_s3" {
  name = "api-s3-access"
  role = module.ecs_fargate_api.task_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_bucket.arn,
          "${aws_s3_bucket.app_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "worker_task_sqs" {
  name = "worker-sqs-consume"
  role = module.ecs_fargate_worker.task_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          module.sqs_main.queue_arn,
          module.sqs_dlq.queue_arn
        ]
      }
    ]
  })
}

// =============================================================
// 9. CloudWatch Log Groups
// =============================================================

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/ecs/${var.environment}-${var.project}-api"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "worker_logs" {
  name              = "/ecs/${var.environment}-${var.project}-worker"
  retention_in_days = 7
}

resource "aws_eip" "bastion" {
  instance = module.bastion.instance_id
  domain   = "vpc"

  tags = {
    Name        = "${var.environment}-${var.project}-bastion-eip"
    Environment = var.environment
    Project     = var.project
  }
}

// =============================================================
// 10. Application Auto Scaling (Worker Queue-Backlog & API CPU)
// =============================================================

# Worker Service — Autoscaling based on SQS Queue Backlog
resource "aws_appautoscaling_target" "worker_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${module.ecs_cluster.cluster_name}/${module.ecs_fargate_worker.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "worker_queue_scaling" {
  name               = "worker-queue-backlog"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker_target.resource_id
  scalable_dimension = aws_appautoscaling_target.worker_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 20
    scale_out_cooldown = 60
    scale_in_cooldown  = 180

    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"

      dimensions {
        name  = "QueueName"
        value = module.sqs_main.queue_name
      }
    }
  }
}

# API Service — Autoscaling based on CPU Utilization
resource "aws_appautoscaling_target" "api_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${module.ecs_cluster.cluster_name}/${module.ecs_fargate_api.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu_scaling" {
  name               = "api-cpu60"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api_target.resource_id
  scalable_dimension = aws_appautoscaling_target.api_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_out_cooldown = 60
    scale_in_cooldown  = 180

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
