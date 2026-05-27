terraform {
    required_version = ">= 1.5.0"
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
    backend "s3" {
        bucket       = "altrx-terraform-state-993197"
        key          = "altrx/staging/terraform.tfstate"
        region       = "us-east-1"
        profile      = "altrx"
        use_lockfile = true
        encrypt      = true
    }
}

provider "aws" {
    region  = var.aws_region
    profile = var.aws_profile 
}

# =============================================================
# Network Modules (VPC, Subnets, Internet Gateway)
# =============================================================
module "vpc" {
    source               = "../../../../modules/vpc"
    vpc_cidr             = var.vpc_cidr
    instance_tenancy     = var.instance_tenancy
    enable_dns_hostnames = var.enable_dns_hostnames
    enable_dns_support   = var.enable_dns_support
    environment          = var.environment
    project              = var.project
}

module "subnets" {
    source          = "../../../../modules/subnets"
    vpc_id          = module.vpc.vpc_id
    public_subnets  = var.public_subnets
    private_subnets = var.private_subnets
    environment     = var.environment
    project         = var.project
}
module "igw" {
    source      = "../../../../modules/igw"
    vpc_id      = module.vpc.vpc_id
    environment = var.environment
    project     = var.project
}

module "eip" {
    source      = "../../../../modules/eip"
    environment = var.environment
    project     = var.project
}

module "nat_gateway" {
    source            = "../../../../modules/nat_gateway"
    eip_allocation_id = module.eip.eip_allocation_id
    public_subnet_id  = module.subnets.public_subnet_ids["public1"]
    environment       = var.environment
    project           = var.project
    igw_dependency    = module.igw.igw_id
}

module "route_tables" {
    source         = "../../../../modules/route_tables"
    vpc_id         = module.vpc.vpc_id
    igw_id         = module.igw.igw_id
    nat_gateway_id = module.nat_gateway.nat_gateway_id
    environment    = var.environment
    project        = var.project
}

module "route_table_association" {
    source                  = "../../../../modules/route_table_association"
    public_subnet_ids       = module.subnets.public_subnet_ids
    private_subnet_ids      = module.subnets.private_subnet_ids
    public_route_table_id   = module.route_tables.public_route_table_id
    private_route_table_id  = module.route_tables.private_route_table_id
}

# =============================================================

# Isolated Security Groups for Staging
# =============================================================
resource "aws_security_group" "staging_redis" {
  description = "Allows Redis traffic"
  egress = [{
    cidr_blocks      = []
    description      = ""
    from_port        = 6379
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = [aws_security_group.staging_be.id]
    self             = false
    to_port          = 6379
  }]
  ingress = [{
    cidr_blocks      = []
    description      = ""
    from_port        = 6379
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = [aws_security_group.staging_be.id]
    self             = false
    to_port          = 6379
  }]
  name                   = "Staging-Redis-Sg"
  revoke_rules_on_delete = null
  tags                   = { Environment = var.environment }
  tags_all               = { Environment = var.environment }
  vpc_id                 = module.vpc.vpc_id
}

resource "aws_security_group" "staging_alb" {
  description = "It allows internet traffic"
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 443
    }, {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 80
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 80
  }]
  name                   = "Staging-ALB-SG"
  revoke_rules_on_delete = null
  tags                   = { Environment = var.environment }
  tags_all               = { Environment = var.environment }
  vpc_id                 = module.vpc.vpc_id
}

resource "aws_security_group" "staging_be" {
  name                   = "Staging-BE-SG"
  revoke_rules_on_delete = null
  tags                   = { Environment = var.environment }
  tags_all               = { Environment = var.environment }
  vpc_id                 = module.vpc.vpc_id
  description = "Allow ALB Traffic"
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress = [{
    cidr_blocks      = []
    description      = ""
    from_port        = 8000
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = [aws_security_group.staging_alb.id]
    self             = false
    to_port          = 8000
  }]
}

resource "aws_security_group" "staging_worker" {
  description = "Allow Outbound and Inbound specific"
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress                = []
  name                   = "Staging-Worker-SG"
  revoke_rules_on_delete = null
  tags                   = { Environment = var.environment }
  tags_all               = { Environment = var.environment }
  vpc_id                 = module.vpc.vpc_id
}

resource "aws_security_group" "staging_wordpress" {
  description = "launch-wizard-1 created 2026-04-20T18:09:51.774Z"
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 22
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 22
    }, {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 443
    }, {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 80
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 80
  }]
  name                   = "staging-wordpress-sg"
  revoke_rules_on_delete = null
  tags                   = { Environment = var.environment }
  tags_all               = { Environment = var.environment }
  vpc_id                 = module.vpc.vpc_id
}

# =============================================================
# Consolidated Databases (DynamoDB & Redis)
# =============================================================
resource "aws_elasticache_subnet_group" "staging_redis" {
  description = "Subnet group for staging redis cluster"
  name        = "staging-sg"
  subnet_ids  = [module.subnets.private_subnet_ids["private1"], module.subnets.private_subnet_ids["private2"]]
}

resource "aws_dynamodb_table" "payment_events_log" {
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = false
  hash_key                    = "event_id"
  name                        = "staging_altrx-payment-events-log"
  range_key                   = "received_at"
  read_capacity               = 0
  stream_enabled              = false
  table_class                 = "STANDARD"
  tags                        = { Environment = var.environment }
  write_capacity              = 0
  attribute {
    name = "event_id"
    type = "S"
  }
  attribute {
    name = "received_at"
    type = "S"
  }
}

resource "aws_elasticache_replication_group" "staging_redis" {
  at_rest_encryption_enabled  = true
  auth_token                  = null
  auto_minor_version_upgrade  = true
  automatic_failover_enabled  = false
  cluster_mode                = "disabled"
  data_tiering_enabled        = false
  description                 = "Staging Redis Cache"
  engine                      = "redis"
  engine_version              = "7.1"
  ip_discovery                = "ipv4"
  maintenance_window          = "thu:04:00-thu:05:00"
  multi_az_enabled            = false
  network_type                = "ipv4"
  node_type                   = "cache.t3.small"
  num_cache_clusters          = 1  # Standard cluster size for staging
  parameter_group_name        = "default.redis7"
  port                        = 6379
  replication_group_id        = "staging-redis"
  security_group_ids          = [aws_security_group.staging_redis.id]
  snapshot_retention_limit    = 1
  snapshot_window             = "06:30-07:30"
  subnet_group_name           = aws_elasticache_subnet_group.staging_redis.name
  tags                        = { Environment = var.environment }
  transit_encryption_enabled  = true
  transit_encryption_mode     = "required"
  log_delivery_configuration {
    destination      = "redis-prod" # Staging uses same logging bucket/group or dedicated log group
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }
}

resource "aws_dynamodb_table" "processed_events" {
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = false
  hash_key                    = "event_id"
  name                        = "staging_altrx-processed-events"
  range_key                   = null
  read_capacity               = 0
  stream_enabled              = false
  table_class                 = "STANDARD"
  tags                        = { Environment = var.environment }
  write_capacity              = 0
  attribute {
    name = "event_id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "stripe_customers" {
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = false
  hash_key                    = "stripe_customer_id"
  name                        = "staging_altrx-stripe-customers"
  range_key                   = null
  read_capacity               = 0
  stream_enabled              = false
  table_class                 = "STANDARD"
  tags                        = { Environment = var.environment }
  write_capacity              = 0
  attribute {
    name = "account"
    type = "S"
  }
  attribute {
    name = "email"
    type = "S"
  }
  attribute {
    name = "stripe_customer_id"
    type = "S"
  }
  global_secondary_index {
    hash_key           = "email"
    name               = "email-account-index"
    projection_type    = "ALL"
    range_key          = "account"
    read_capacity      = 0
    write_capacity     = 0
  }
}

resource "aws_dynamodb_table" "checkout_submissions" {
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = false # False for staging to avoid delete blockages
  hash_key                    = "submission_token"
  name                        = "staging_altrx-checkout-submissions"
  range_key                   = null
  read_capacity               = 0
  stream_enabled              = false
  table_class                 = "STANDARD"
  tags                        = { Environment = var.environment }
  write_capacity              = 0
  attribute {
    name = "provider_id"
    type = "S"
  }
  attribute {
    name = "submission_token"
    type = "S"
  }
  global_secondary_index {
    hash_key           = "provider_id"
    name               = "provider_id-index"
    projection_type    = "ALL"
    read_capacity      = 0
    write_capacity     = 0
  }
}

# =============================================================
# Consolidated Load Balancing (ALB, Listeners, Target Groups)
# =============================================================
resource "aws_lb_listener" "staging_http" {
  load_balancer_arn                    = aws_lb.staging_alb.arn
  port                                 = 80
  protocol                             = "HTTP"
  routing_http_response_server_enabled = true
  tags                                 = { Environment = var.environment }
  default_action {
    type             = "redirect"
    redirect {
      host        = "#{host}"
      path        = "/#{path}"
      port        = "443"
      protocol    = "HTTPS"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "staging_https" {
  certificate_arn                      = "arn:aws:acm:us-east-1:692137657276:certificate/33647a6f-f1c6-4ae8-aa6e-a58602892404"
  load_balancer_arn                    = aws_lb.staging_alb.arn
  port                                 = 443
  protocol                             = "HTTPS"
  routing_http_response_server_enabled = true
  ssl_policy                           = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  tags                                 = { Environment = var.environment }
  default_action {
    target_group_arn = aws_lb_target_group.staging_backend.arn
    type             = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.staging_backend.arn
        weight = 1
      }
    }
  }
}

resource "aws_lb_target_group" "staging_backend" {
  deregistration_delay               = "300"
  ip_address_type                    = "ipv4"
  load_balancing_algorithm_type      = "round_robin"
  load_balancing_anomaly_mitigation  = "off"
  load_balancing_cross_zone_enabled  = "use_load_balancer_configuration"
  name                               = "Staging-Backend"
  port                               = 8000
  protocol                           = "HTTP"
  protocol_version                   = "HTTP1"
  tags                               = { Environment = var.environment }
  target_type                        = "ip"
  vpc_id                             = module.vpc.vpc_id
  health_check {
    enabled             = true
    healthy_threshold   = 5
    interval            = 30
    matcher             = "200"
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb" "staging_alb" {
  client_keep_alive                           = 3600
  desync_mitigation_mode                      = "defensive"
  enable_cross_zone_load_balancing            = true
  enable_deletion_protection                  = false
  enable_http2                                = true
  idle_timeout                                = 60
  internal                                    = false
  ip_address_type                             = "ipv4"
  load_balancer_type                          = "application"
  name                                        = "Staging-ALB"
  preserve_host_header                        = false
  security_groups                             = [aws_security_group.staging_alb.id]
  subnets                                     = [module.subnets.public_subnet_ids["public1"], module.subnets.public_subnet_ids["public2"]]
  tags                                        = { Environment = var.environment }
}

# =============================================================
# Consolidated SQS Queues
# =============================================================
resource "aws_sqs_queue" "staging_altrx_payment_events_dlq" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  max_message_size                  = 262144
  message_retention_seconds         = 1209600
  name                              = "staging_altrx-payment-events-dlq"
  receive_wait_time_seconds         = 0
  sqs_managed_sse_enabled           = true
  tags                              = { Environment = var.environment }
  visibility_timeout_seconds        = 30
}

resource "aws_sqs_queue" "staging_altrx_payment_events" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  max_message_size                  = 262144
  message_retention_seconds         = 345600
  name                              = "staging_altrx-payment-events"
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:staging_altrx-payment-events"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
  receive_wait_time_seconds = 0
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.staging_altrx_payment_events_dlq.arn
    maxReceiveCount     = 5
  })
  sqs_managed_sse_enabled    = true
  tags                       = { Environment = var.environment }
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue" "altrx_reconciler_trigger_dlq" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  max_message_size                  = 262144
  message_retention_seconds         = 1209600
  name                              = "altrx-reconciler-trigger-dlq-staging"
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger-dlq-staging"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
  receive_wait_time_seconds  = 0
  sqs_managed_sse_enabled    = true
  tags                       = { Environment = var.environment }
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue" "altrx_reconciler_trigger" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  max_message_size                  = 262144
  message_retention_seconds         = 345600
  name                              = "altrx-reconciler-trigger-staging"
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger-staging"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
  receive_wait_time_seconds = 0
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.altrx_reconciler_trigger_dlq.arn
    maxReceiveCount     = 5
  })
  sqs_managed_sse_enabled    = true
  tags                       = { Environment = var.environment }
  visibility_timeout_seconds = 660
}

# =============================================================
# Consolidated CloudWatch Logging Groups
# =============================================================
resource "aws_cloudwatch_log_group" "staging_worker" {
  log_group_class   = "STANDARD"
  name              = "/ecs/staging-worker"
  retention_in_days = 7
  tags              = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "reconciler" {
  log_group_class   = "STANDARD"
  name              = "/aws/lambda/altrx-reconciler-staging"
  retention_in_days = 7
  tags              = { Environment = var.environment }
}


resource "aws_cloudwatch_log_group" "redis_staging" {
  log_group_class   = "STANDARD"
  name              = "redis-staging"
  retention_in_days = 7
  tags              = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "staging_backend" {
  log_group_class   = "STANDARD"
  name              = "/ecs/staging-backend"
  retention_in_days = 7
  tags              = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "ecs_performance" {
  log_group_class   = "STANDARD"
  name              = "/aws/ecs/containerinsights/Staging-Altrx/performance"
  retention_in_days = 1
  tags              = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "staging_worker_payment" {
  log_group_class   = "STANDARD"
  name              = "/ecs/Staging-Worker-Payment"
  retention_in_days = 7
  tags              = { Environment = var.environment }
}

# =============================================================
# Consolidated IAM Roles & Policies (Fully Isolated Suffixes)
# =============================================================


resource "aws_iam_role" "ecs_task_execution_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ecs:us-east-1:692137657276:*"
        }
        StringEquals = {
          "aws:SourceAccount" = "692137657276"
        }
      }
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  name                  = "ECS-Task-execution-role-staging"
  path                  = "/"
}

resource "aws_iam_role" "altrx_ssm_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  name                  = "altrx_ssm_role_staging"
  path                  = "/"
}



resource "aws_iam_policy" "altrx_reconciler_policy" {
  name        = "AltrxReconcilerPolicy-staging"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:DescribeTable"]
      Effect   = "Allow"
      Resource = ["arn:aws:dynamodb:us-east-1:692137657276:table/staging_altrx-checkout-submissions", "arn:aws:dynamodb:us-east-1:692137657276:table/staging_altrx-checkout-submissions/index/*", "arn:aws:dynamodb:us-east-1:692137657276:table/staging_altrx-stripe-customers", "arn:aws:dynamodb:us-east-1:692137657276:table/staging_altrx-stripe-customers/index/*", "arn:aws:dynamodb:us-east-1:692137657276:table/staging_altrx-processed-events", "arn:aws:dynamodb:us-east-1:692137657276:table/staging_altrx-payment-events-log", "arn:aws:dynamodb:us-east-1:692137657276:table/staging_altrx-payment-events-log/index/*"]
      Sid      = "DynamoDBAccess"
      }, {
      Action   = ["sqs:SendMessage"]
      Effect   = "Allow"
      Resource = aws_sqs_queue.altrx_reconciler_trigger.arn
      Sid      = "SQSSelfChain"
      }, {
      Action   = ["secretsmanager:GetSecretValue"]
      Effect   = "Allow"
      Resource = "arn:aws:secretsmanager:us-east-1:692137657276:secret:staging_altrx/*"
      Sid      = "SecretsManagerAccess"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role" "altrx_reconciler_lambda_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  name                  = "AltrxReconcilerLambdaRole-staging"
  path                  = "/"
}

# --- IAM Role Policy Attachments ---
resource "aws_iam_role_policy_attachment" "reconciler_lambda_attach" {
  role       = aws_iam_role.altrx_reconciler_lambda_role.name
  policy_arn = aws_iam_policy.altrx_reconciler_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_role_attach" {
  role       = aws_iam_role.altrx_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# =============================================================

# Consolidated Compute (ECS, Lambda, Amplify, ECR)
# =============================================================
resource "aws_ecr_repository" "staging_worker" {
  image_tag_mutability = "MUTABLE"
  name                 = "staging-worker"
  encryption_configuration {
    encryption_type = "AES256"
  }
  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecs_task_definition" "staging_backend" {
  family                   = "staging-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "backend"
    image     = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.staging_backend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])
}

resource "aws_ecs_service" "staging_backend" {
  availability_zone_rebalancing      = "ENABLED"
  cluster                            = aws_ecs_cluster.staging.arn
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1
  enable_ecs_managed_tags            = true
  enable_execute_command             = false
  name                               = "Staging-Backend"
  platform_version                   = "1.4.0"
  scheduling_strategy                = "REPLICA"
  task_definition                    = aws_ecs_task_definition.staging_backend.arn
  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE"
    weight            = 1
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller {
    type = "ECS"
  }
  load_balancer {
    container_name   = "backend"
    container_port   = 8000
    target_group_arn = aws_lb_target_group.staging_backend.arn
  }
  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.staging_be.id]
    subnets          = [module.subnets.private_subnet_ids["private1"], module.subnets.private_subnet_ids["private2"]]
  }
}

resource "aws_ecs_cluster" "staging" {
  name     = "Staging-Altrx"
  configuration {
    execute_command_configuration {
      logging    = "DEFAULT"
    }
  }
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_lambda_function" "altrx_reconciler" {
  architectures                      = ["x86_64"]
  function_name                      = "altrx-reconciler-staging"
  image_uri                          = "692137657276.dkr.ecr.us-east-1.amazonaws.com/altrx-reconciler:v-26-05-1527" # Staging reconciler image
  memory_size                        = 512
  package_type                       = "Image"
  reserved_concurrent_executions     = -1
  role                               = aws_iam_role.altrx_reconciler_lambda_role.arn
  timeout                            = 600
  environment {
    variables = var.reconciler_env_vars
  }
  ephemeral_storage {
    size = 512
  }
  logging_config {
    log_format            = "Text"
    log_group             = aws_cloudwatch_log_group.reconciler.name
  }
  tracing_config {
    mode = "PassThrough"
  }
}

resource "aws_ecr_repository" "reconciler" {
  image_tag_mutability = "MUTABLE"
  name                 = "staging-reconciler"
  encryption_configuration {
    encryption_type = "AES256"
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_task_definition" "staging_worker_payment" {
  family                   = "Staging-Worker-Payment"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "worker-payment"
    image     = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
    cpu       = 256
    memory    = 512
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.staging_worker_payment.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "worker-payment"
      }
    }
  }])
}

resource "aws_ecs_service" "staging_worker_payment" {
  availability_zone_rebalancing      = "ENABLED"
  cluster                            = aws_ecs_cluster.staging.arn
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1 # Sized down for staging cost-efficiency
  enable_ecs_managed_tags            = true
  enable_execute_command             = false
  name                               = "Staging-Worker-Payment"
  platform_version                   = "LATEST"
  scheduling_strategy                = "REPLICA"
  task_definition                    = aws_ecs_task_definition.staging_worker_payment.arn
  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE"
    weight            = 1
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller {
    type = "ECS"
  }
  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.staging_worker.id]
    subnets          = [module.subnets.private_subnet_ids["private1"], module.subnets.private_subnet_ids["private2"]]
  }
}

resource "aws_ecr_repository" "staging_backend" {
  image_tag_mutability = "MUTABLE"
  name                 = "staging-backend"
  encryption_configuration {
    encryption_type = "AES256"
  }
  image_scanning_configuration {
    scan_on_push = false
  }
}

