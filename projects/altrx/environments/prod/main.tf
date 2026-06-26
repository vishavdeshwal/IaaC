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
    key          = "altrx/prod/terraform.tfstate"
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



module "vpc" {
  source               = "../../../../modules/aws/vpc"
  vpc_cidr             = var.vpc_cidr
  instance_tenancy     = var.instance_tenancy
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  environment          = var.environment
  project              = var.project
}

module "subnets" {
  source          = "../../../../modules/aws/subnets"
  vpc_id          = module.vpc.vpc_id
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  environment     = var.environment
  project         = var.project
}

module "igw" {
  source      = "../../../../modules/aws/igw"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
}


# =============================================================
# Isolated Security Groups for Production
# =============================================================

module "prod_redis_sg" {
  source        = "../../../../modules/aws/security_groups"
  name          = "redis"
  vpc_id        = module.vpc.vpc_id
  environment   = var.environment
  project       = var.project
  name_override = "Prod-Redis-Sg"
  description   = "Allows Redis traffic"

  ingress_rules = [{
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    cidr_blocks     = []
    security_groups = [module.prod_be_sg.security_group_id]
    description     = ""
  }]

  egress_rules = [{
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    cidr_blocks     = []
    security_groups = [module.prod_be_sg.security_group_id]
    description     = ""
  }]
}

module "prod_alb_sg" {
  source        = "../../../../modules/aws/security_groups"
  name          = "alb"
  vpc_id        = module.vpc.vpc_id
  environment   = var.environment
  project       = var.project
  name_override = "Prod-ALB-SG"
  description   = "It allows internet traffic"

  ingress_rules = [{
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = ""
    }, {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = ""
  }]

  egress_rules = [{
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = ""
  }]
}

resource "aws_security_group" "default" {
  description = "default VPC security group"
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
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = true
    to_port          = 0
  }]
  name                   = "default"
  revoke_rules_on_delete = null
  tags                   = {}
  tags_all               = {}
  vpc_id                 = module.vpc.vpc_id
}

module "prod_be_sg" {
  source        = "../../../../modules/aws/security_groups"
  name          = "be"
  vpc_id        = module.vpc.vpc_id
  environment   = var.environment
  project       = var.project
  name_override = "Prod-BE-SG"
  description   = "Allow ALB Traffic"

  ingress_rules = [{
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    cidr_blocks     = []
    security_groups = [module.prod_alb_sg.security_group_id]
    description     = ""
  }]

  egress_rules = [{
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = ""
  }]
}

module "prod_worker_sg" {
  source        = "../../../../modules/aws/security_groups"
  name          = "worker"
  vpc_id        = module.vpc.vpc_id
  environment   = var.environment
  project       = var.project
  name_override = "Worker-SG"
  description   = "Allow Outbound and Inbound specific"

  ingress_rules = []

  egress_rules = [{
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = ""
  }]
}

module "prod_wordpress_sg" {
  source        = "../../../../modules/aws/security_groups"
  name          = "wordpress"
  vpc_id        = module.vpc.vpc_id
  environment   = var.environment
  project       = var.project
  name_override = "wordpress-sg"
  description   = "launch-wizard-1 created 2026-04-20T18:09:51.774Z"

  ingress_rules = [{
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = ""
    }, {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = ""
    }, {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = ""
  }]

  egress_rules = [{
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = ""
  }]
}


# =============================================================
# Consolidated Databases (DynamoDB & Redis)
# =============================================================

module "prod_redis" {
  source                     = "../../../../modules/aws/elasticache"
  name                       = "redis"
  engine                     = "redis"
  node_type                  = "cache.t3.small"
  num_cache_clusters         = 2
  transit_encryption         = true
  at_rest_encryption         = true
  auth_token                 = null
  maintenance_window         = "thu:04:00-thu:05:00"
  snapshot_retention_limit   = 1
  snapshot_window            = "06:30-07:30"
  subnet_ids                 = [module.subnets.public_subnet_ids["public2"], module.subnets.private_subnet_ids["private1"]]
  security_group_ids         = [module.prod_redis_sg.security_group_id]
  environment                = var.environment
  project                    = var.project
  name_override              = "prod-redis"
  subnet_group_name_override = "prod-sg"
  apply_immediately          = true
}

module "dynamodb_payment_events_log" {
  source       = "../../../../modules/aws/dynamodb"
  name         = "production_altrx-payment-events-log"
  hash_key     = "event_id"
  range_key    = "received_at"
  billing_mode = "PAY_PER_REQUEST"
  environment  = var.environment
  project      = var.project
  attributes = [
    { name = "event_id", type = "S" },
    { name = "received_at", type = "S" }
  ]
}

module "dynamodb_processed_events" {
  source       = "../../../../modules/aws/dynamodb"
  name         = "production_altrx-processed-events"
  hash_key     = "event_id"
  billing_mode = "PAY_PER_REQUEST"
  environment  = var.environment
  project      = var.project
  attributes = [
    { name = "event_id", type = "S" }
  ]
}

module "dynamodb_stripe_customers" {
  source       = "../../../../modules/aws/dynamodb"
  name         = "production_altrx-stripe-customers"
  hash_key     = "stripe_customer_id"
  billing_mode = "PAY_PER_REQUEST"
  environment  = var.environment
  project      = var.project
  attributes = [
    { name = "account", type = "S" },
    { name = "email", type = "S" },
    { name = "stripe_customer_id", type = "S" }
  ]
  global_secondary_indexes = [
    {
      name            = "email-account-index"
      hash_key        = "email"
      range_key       = "account"
      projection_type = "ALL"
    }
  ]
}

module "dynamodb_checkout_submissions" {
  source                      = "../../../../modules/aws/dynamodb"
  name                        = "production_altrx-checkout-submissions"
  hash_key                    = "submission_token"
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true
  environment                 = var.environment
  project                     = var.project
  attributes = [
    { name = "provider_id", type = "S" },
    { name = "submission_token", type = "S" }
  ]
  global_secondary_indexes = [
    {
      name            = "provider_id-index"
      hash_key        = "provider_id"
      projection_type = "ALL"
    }
  ]
}

module "dynamodb_weight_logs" {
  source                      = "../../../../modules/aws/dynamodb"
  name                        = "production_altrx-weight-logs"
  hash_key                    = "user_id"
  range_key                   = "log_date"
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true
  environment                 = var.environment
  project                     = var.project
  attributes = [
    { name = "user_id", type = "S" },
    { name = "log_date", type = "S" },
    { name = "email", type = "S" }
  ]
  global_secondary_indexes = [
    {
      name            = "email-index"
      hash_key        = "email"
      projection_type = "ALL"
    }
  ]
}



# =============================================================
# Consolidated Load Balancing (ALB, Listeners, Target Groups)
# =============================================================

module "prod_target_group" {
  source                = "../../../../modules/aws/target_group"
  name                  = "backend"
  port                  = 8000
  protocol              = "HTTP"
  target_type           = "ip"
  vpc_id                = module.vpc.vpc_id
  deregistration_delay  = 300
  health_check_path     = "/healthz"
  health_check_protocol = "HTTP"
  health_check_port     = "traffic-port"
  health_check_interval = 30
  health_check_timeout  = 5
  healthy_threshold     = 5
  unhealthy_threshold   = 2
  health_check_matcher  = "200"
  environment           = var.environment
  project               = var.project
  name_override         = "Prod-Backend"
}

module "prod_alb" {
  source                     = "../../../../modules/aws/alb"
  name                       = "alb"
  internal                   = false
  security_group_ids         = [module.prod_alb_sg.security_group_id]
  subnet_ids                 = [module.subnets.public_subnet_ids["public2"], module.subnets.public_subnet_ids["public1"]]
  enable_deletion_protection = false
  idle_timeout               = 60
  enable_http2               = true
  http_port                  = 80
  http_default_action        = "redirect_to_https"
  https_port                 = 443
  certificate_arn            = "arn:aws:acm:us-east-1:692137657276:certificate/33647a6f-f1c6-4ae8-aa6e-a58602892404"
  https_target_group_arn     = module.prod_target_group.target_group_arn
  ssl_policy                 = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  environment                = var.environment
  project                    = var.project
  name_override              = "Prod-ALB"
}


# =============================================================
# Consolidated SQS Queues
# =============================================================

module "prod_payment_events_dlq" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "payment-events-dlq"
  environment                = var.environment
  project                    = var.project
  name_override              = "production_altrx-payment-events-dlq"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600
  max_message_size           = 262144
  delay_seconds              = 0
  receive_wait_time_seconds  = 0
}

module "prod_payment_events" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "payment-events"
  environment                = var.environment
  project                    = var.project
  name_override              = "production_altrx-payment-events"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  max_message_size           = 262144
  delay_seconds              = 0
  receive_wait_time_seconds  = 0
  dlq_arn                    = module.prod_payment_events_dlq.queue_arn
  max_receive_count          = 5
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:production_altrx-payment-events"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
}

module "prod_reconciler_trigger_dlq" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "reconciler-trigger-dlq"
  environment                = var.environment
  project                    = var.project
  name_override              = "altrx-reconciler-trigger-dlq"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600
  max_message_size           = 262144
  delay_seconds              = 0
  receive_wait_time_seconds  = 0
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger-dlq"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
}

module "prod_reconciler_trigger" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "reconciler-trigger"
  environment                = var.environment
  project                    = var.project
  name_override              = "altrx-reconciler-trigger"
  visibility_timeout_seconds = 660
  message_retention_seconds  = 345600
  max_message_size           = 262144
  delay_seconds              = 0
  receive_wait_time_seconds  = 0
  dlq_arn                    = module.prod_reconciler_trigger_dlq.queue_arn
  max_receive_count          = 5
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
}


# =============================================================
# Consolidated CloudWatch Logging Groups
# =============================================================

resource "aws_cloudwatch_log_group" "prod_worker" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/ecs/prod-worker"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

resource "aws_cloudwatch_log_group" "reconciler" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/aws/lambda/altrx-reconciler"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

resource "aws_cloudwatch_log_group" "redis_prod" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "redis-prod"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

resource "aws_cloudwatch_log_group" "prod_backend" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/ecs/prod-backend"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

resource "aws_cloudwatch_log_group" "ecs_performance" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/aws/ecs/containerinsights/Prod-Altrx/performance"
  retention_in_days = 1
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

resource "aws_cloudwatch_log_group" "prod_worker_payment" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/ecs/Prod-Worker-Payment"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}


# =============================================================
# Consolidated IAM Roles & Policies
# =============================================================


resource "aws_iam_policy" "ecs_s3_env_policy" {
  name        = "${var.environment}-ecs-s3-env-policy"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = ["s3:GetObject"]
      Effect   = "Allow"
      Resource = [
        "arn:aws:s3:::production-${lower(var.project)}-v3-uploads/worker-env/worker.env",
        "arn:aws:s3:::production-${lower(var.project)}-v3-uploads/backend-env/backend.env"
      ]
      }, {
      Action   = ["s3:GetBucketLocation"]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::production-${lower(var.project)}-v3-uploads"
    }]
    Version = "2012-10-17"
  })
}

module "iam_ecs_task_execution_role" {
  source      = "../../../../modules/aws/iam_role"
  name        = "ECS-Task-execution-role"
  environment = var.environment
  project     = var.project
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
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

resource "aws_iam_role_policy_attachment" "ecs_s3_env_attachment" {
  role       = module.iam_ecs_task_execution_role.role_name
  policy_arn = aws_iam_policy.ecs_s3_env_policy.arn
}

resource "aws_iam_policy" "ecs_dynamodb_sqs_policy" {
  name        = "production-ecs-dynamodb-sqs-policy"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:DescribeTable",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem"
      ]
      Effect   = "Allow"
      Resource = [
        "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-*",
        "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-*/index/*"
      ]
      Sid      = "DynamoDBAccess"
      }, {
      Action   = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ChangeMessageVisibility"
      ]
      Effect   = "Allow"
      Resource = [
        "arn:aws:sqs:us-east-1:692137657276:production_altrx-*",
        "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger",
        "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger-dlq"
      ]
      Sid      = "SQSAccess"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_dynamodb_sqs_attachment" {
  role       = module.iam_ecs_task_execution_role.role_name
  policy_arn = aws_iam_policy.ecs_dynamodb_sqs_policy.arn
}


module "iam_altrx_ssm_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "altrx_ssm_role"
  # This role is also managed by staging (module.iam_strapie_server_role) since
  # IAM role names are account-global. Use a shared tag value so both
  # environments converge on the same desired state instead of fighting.
  environment = "shared"
  project     = var.project
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
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_policy" "altrx_reconciler_policy" {
  description = null
  name        = "AltrxReconcilerPolicy"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:DescribeTable"]
      Effect   = "Allow"
      Resource = ["arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-checkout-submissions", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-checkout-submissions/index/*", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-stripe-customers", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-stripe-customers/index/*", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-processed-events", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-events-log", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-events-log/index/*", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-weight-logs", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-weight-logs/index/*"]
      Sid      = "DynamoDBAccess"
      }, {
      Action   = ["sqs:SendMessage"]
      Effect   = "Allow"
      Resource = "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger"
      Sid      = "SQSSelfChain"
      }, {
      Action   = ["secretsmanager:GetSecretValue"]
      Effect   = "Allow"
      Resource = "arn:aws:secretsmanager:us-east-1:692137657276:secret:production_altrx/*"
      Sid      = "SecretsManagerAccess"
    }]
    Version = "2012-10-17"
  })
  tags     = {}
  tags_all = {}
}


# =============================================================
# Consolidated Compute (ECS, Lambda, Amplify, ECR)
# =============================================================

module "ecr_prod_worker" {
  source               = "../../../../modules/aws/ecr"
  name                 = "worker"
  environment          = var.environment
  project              = var.project
  name_override        = "prod-worker"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
}

module "ecs_cluster" {
  source                    = "../../../../modules/aws/ecs_cluster"
  cluster_name              = "Prod-Altrx"
  enable_container_insights = true
  environment               = var.environment
  project                   = var.project
}

# CI/CD registers new revisions for these families directly; always pick up
# whatever is currently the latest ACTIVE revision instead of hardcoding one.
data "aws_ecs_task_definition" "prod_backend" {
  task_definition = "prod-backend"
}

data "aws_ecs_task_definition" "prod_worker_payment" {
  task_definition = "Prod-Worker-Payment"
}

module "ecs_backend_service" {
  source                       = "../../../../modules/aws/ecs_service"
  service_name                 = "Prod-Backend"
  family                       = "prod-backend"
  cluster_arn                  = module.ecs_cluster.cluster_arn
  cpu                          = "512"
  memory                       = "1024"
  execution_role_arn           = module.iam_ecs_task_execution_role.role_arn
  task_role_arn                = module.iam_ecs_task_execution_role.role_arn
  desired_count                = 1
  platform_version             = "1.4.0"
  launch_type                  = var.ecs_launch_type
  task_definition_arn_override = data.aws_ecs_task_definition.prod_backend.arn

  subnet_ids         = [module.subnets.private_subnet_ids["private3"], module.subnets.private_subnet_ids["private4"]]
  security_group_ids = [module.prod_be_sg.security_group_id]
  assign_public_ip   = false

  depends_on = [
    aws_iam_role_policy_attachment.ecs_s3_env_attachment,
    aws_iam_role_policy_attachment.ecs_dynamodb_sqs_attachment
  ]

  container_definitions = jsonencode([{
    name      = "backend"
    image     = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
    cpu       = 512
    memory    = 1024
    essential = true
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
    }]
    environmentFiles = [{
      value = "arn:aws:s3:::production-${lower(var.project)}-v3-uploads/backend-env/backend.env"
      type  = "s3"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.prod_backend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])

  target_group_arn = module.prod_target_group.target_group_arn
  container_name   = "backend"
  container_port   = 8000

  enable_circuit_breaker = true
  capacity_providers = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 0
    }
  ]

  environment = var.environment
  project     = var.project
}

module "lambda_reconciler" {
  source                 = "../../../../modules/aws/lambda"
  function_name          = "reconciler"
  environment            = var.environment
  project                = var.project
  name_override          = "altrx-reconciler"
  role_name_override     = "AltrxReconcilerLambdaRole"
  image_uri              = "692137657276.dkr.ecr.us-east-1.amazonaws.com/altrx-reconciler:v-26-05-1527"
  memory_size            = 512
  timeout                = 600
  environment_variables  = var.reconciler_env_vars
  additional_policy_arns = [aws_iam_policy.altrx_reconciler_policy.arn]
  ecr_repository_name    = module.ecr_reconciler.repository_name
  ecr_repository_arn     = module.ecr_reconciler.repository_arn
}

module "ecr_reconciler" {
  source               = "../../../../modules/aws/ecr"
  name                 = "reconciler"
  environment          = var.environment
  project              = var.project
  name_override        = "altrx-reconciler"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
}

module "ecs_worker_service" {
  source                       = "../../../../modules/aws/ecs_service"
  service_name                 = "Prod-Worker-Payment"
  family                       = "Prod-Worker-Payment"
  cluster_arn                  = module.ecs_cluster.cluster_arn
  cpu                          = "256"
  memory                       = "512"
  execution_role_arn           = module.iam_ecs_task_execution_role.role_arn
  task_role_arn                = module.iam_ecs_task_execution_role.role_arn
  desired_count                = 2
  platform_version             = "LATEST"
  launch_type                  = var.ecs_launch_type
  task_definition_arn_override = data.aws_ecs_task_definition.prod_worker_payment.arn

  subnet_ids         = [module.subnets.private_subnet_ids["private3"], module.subnets.private_subnet_ids["private4"]]
  security_group_ids = [module.prod_worker_sg.security_group_id]
  assign_public_ip   = true

  depends_on = [
    aws_iam_role_policy_attachment.ecs_s3_env_attachment,
    aws_iam_role_policy_attachment.ecs_dynamodb_sqs_attachment
  ]

  container_definitions = jsonencode([{
    name      = "worker-payment"
    image     = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
    cpu       = 256
    memory    = 512
    essential = true
    environmentFiles = [{
      value = "arn:aws:s3:::production-${lower(var.project)}-v3-uploads/worker-env/worker.env"
      type  = "s3"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.prod_worker_payment.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "worker-payment"
      }
    }
  }])

  enable_circuit_breaker = true
  capacity_providers = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 0
    }
  ]

  environment = var.environment
  project     = var.project
}

module "ecr_prod_backend" {
  source               = "../../../../modules/aws/ecr"
  name                 = "backend"
  environment          = var.environment
  project              = var.project
  name_override        = "prod-backend"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
}


# Consolidated S3 Storage (Importing existing bucket)
# =============================================================
resource "aws_s3_bucket" "uploads" {
  bucket = var.environment == "prod" ? "production-${lower(var.project)}-v3-uploads" : "${var.environment}-${lower(var.project)}-v3-uploads"

  tags = {
    Name        = var.environment == "prod" ? "production-${lower(var.project)}-v3-uploads" : "${var.environment}-${lower(var.project)}-v3-uploads"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_s3_bucket_cors_configuration" "uploads_cors" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_headers = ["Content-Type"]
    allowed_methods = ["PUT", "GET"]
    allowed_origins = [
      "https://altrx.com",
      "https://www.altrx.com",
      "https://main.dsx3g35brvnhn.amplifyapp.com",
      "https://dsx3g35brvnhn.amplifyapp.com",
      "https://staging-olh.d9m305ipl0ufl.amplifyapp.com",
      "https://d9m305ipl0ufl.amplifyapp.com",
      "http://localhost:3000"
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}


# =============================================================
# Strapie Infrastructure (Modularized)
# =============================================================

# 1. EC2 Security Group (Using modules/security_groups)
module "sg_strapie" {
  source        = "../../../../modules/aws/security_groups"
  vpc_id        = module.vpc.vpc_id
  name          = "strapie"
  name_override = "Prod-Strapie-SG"
  description   = "It allows all traffic to strapie"
  environment   = var.environment
  project       = var.project

  ingress_rules = [
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "Allow SSH access from anywhere"
    },
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "Allow HTTP access from anywhere"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "Allow HTTPS access from anywhere"
    }
  ]

  egress_rules = [
    {
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "Allow all outbound"
    }
  ]
}

# 2. Database Security Group (Using modules/security_groups)
module "sg_strapie_db" {
  source        = "../../../../modules/aws/security_groups"
  vpc_id        = module.vpc.vpc_id
  name          = "strapie-db"
  name_override = "Prod-Strapie-DB-SG"
  description   = "it allows traffic from strapie-sg"
  environment   = var.environment
  project       = var.project

  ingress_rules = [
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      cidr_blocks     = []
      security_groups = [module.sg_strapie.security_group_id]
      description     = "Postgres inbound from EC2"
    }
  ]

  egress_rules = [
    {
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "Allow all outbound"
    }
  ]
}

# 3 & 4. Database Subnet Group & DB Instance (Using modules/rds)
module "prod_strapie_db" {
  source                = "../../../../modules/aws/rds"
  identifier            = "strapie-db"
  allocated_storage     = 100
  max_allocated_storage = 1000
  engine                = "postgres"
  engine_version        = "18.3"
  instance_class        = "db.m7g.large"
  username              = "postgres"
  password              = "ProductionSecurePass123!"

  subnet_ids             = [
    module.subnets.private_subnet_ids["private1"],
    module.subnets.private_subnet_ids["private4"]
  ]
  security_group_ids     = [module.sg_strapie_db.security_group_id]
  multi_az               = true
  publicly_accessible    = false
  storage_encrypted      = true
  backup_retention_period = 7
  backup_window          = "07:13-07:43"
  maintenance_window     = "wed:09:57-wed:10:27"
  skip_final_snapshot    = true
  environment            = var.environment
  project                = var.project
}

# 5. EC2 Instance Profile (Uses the existing global "altrx_ssm_role")
resource "aws_iam_instance_profile" "strapie_profile" {
  name = "production-altrx-strapie-profile"
  role = module.iam_altrx_ssm_role.role_name
}

# 5.1 Production Strapie EC2 Server (Using modules/ec2)
module "production_strapie_server" {
  source                = "../../../../modules/aws/ec2"
  name                  = "strapie"
  name_override         = "Prod-Strapie-Server"
  ami_id                = "ami-091138d0f0d41ff90"
  instance_type         = "t2.medium"
  subnet_id             = module.subnets.public_subnet_ids["public1"]
  security_group_ids    = [module.sg_strapie.security_group_id]
  iam_instance_profile  = aws_iam_instance_profile.strapie_profile.name
  associate_public_ip   = true
  root_volume_size      = 50
  root_volume_type      = "gp3"
  root_volume_encrypted = true
  environment           = var.environment
  project               = var.project
}

# 5.2 Elastic IP for Strapie Server (Using modules/eip)
module "production_strapie_eip" {
  source        = "../../../../modules/aws/eip"
  environment   = var.environment
  project       = var.project
  name          = "strapie-eip"
  name_override = "Prod-strapie-EIP"
  instance_id   = module.production_strapie_server.instance_id
}

# 6. S3 Bucket for strapie Uploads
resource "aws_s3_bucket" "strapie_uploads" {
  bucket = var.environment == "prod" ? "production-${lower(var.project)}-strapie-uploads" : "${var.environment}-${lower(var.project)}-strapie-uploads"

  tags = {
    Name        = var.environment == "prod" ? "production-${lower(var.project)}-strapie-uploads" : "${var.environment}-${lower(var.project)}-strapie-uploads"
    Environment = var.environment
    Project     = var.project
  }
}


# 7. IAM Policy & Attachment (Using modules/iam_policy)
module "strapie_s3_policy" {
  source      = "../../../../modules/aws/iam_policy"
  name        = "${var.environment}-${var.project}-strapie-s3-access"
  description = "Allows Production Strapie Server to access its dedicated S3 bucket"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.strapie_uploads.arn,
          "${aws_s3_bucket.strapie_uploads.arn}/*"
        ]
      }
    ]
  })
  role_name   = module.iam_altrx_ssm_role.role_name
  environment = var.environment
  project     = var.project
}

# 8. S3 Bucket Public Access Configuration for Strapi Uploads
resource "aws_s3_bucket_public_access_block" "strapie_uploads_public_access" {
  bucket = aws_s3_bucket.strapie_uploads.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "strapie_uploads_public_policy" {
  bucket = aws_s3_bucket.strapie_uploads.id

  depends_on = [aws_s3_bucket_public_access_block.strapie_uploads_public_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.strapie_uploads.arn}/*"
      }
    ]
  })
}

# =============================================================
# Consolidated SQS Queues for cv-case-events
# =============================================================
module "cv_case_events_dlq" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "cv-case-events-dlq"
  environment                = var.environment
  project                    = var.project
  name_override              = var.environment == "prod" ? "cv-case-events-dlq.fifo" : "cv-case-events-dlq-${var.environment}.fifo"
  fifo_queue                 = true
  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600
  max_message_size           = 262144
  delay_seconds              = 0
  receive_wait_time_seconds  = 0
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:${var.environment == "prod" ? "cv-case-events-dlq.fifo" : "cv-case-events-dlq-${var.environment}.fifo"}"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
}

module "cv_case_events" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "cv-case-events"
  environment                = var.environment
  project                    = var.project
  name_override              = var.environment == "prod" ? "cv-case-events.fifo" : "cv-case-events-${var.environment}.fifo"
  fifo_queue                 = true
  content_based_deduplication = false
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  max_message_size           = 262144
  delay_seconds              = 0
  receive_wait_time_seconds  = 0
  dlq_arn                    = module.cv_case_events_dlq.queue_arn
  max_receive_count          = 5
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:${var.environment == "prod" ? "cv-case-events.fifo" : "cv-case-events-${var.environment}.fifo"}"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
}

# =============================================================
# Consolidated CloudWatch Logging Groups
# =============================================================
module "prod_cv_case_events_log_group" {
  source            = "../../../../modules/aws/cloudwatch_log_group"
  name              = "/ecs/Prod-CvCaseEvents"
  retention_in_days = 7
  tags = {
    Name        = "/ecs/Prod-CvCaseEvents"
    Environment = var.environment
    Project     = var.project
  }
}

# =============================================================
# Compute and IAM for cv-case-events
# =============================================================
module "ecr_prod_cv_case_events" {
  source               = "../../../../modules/aws/ecr"
  name                 = "cv-case-events"
  environment          = var.environment
  project              = var.project
  name_override        = "prod-cv-case-events"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
}

data "aws_iam_policy_document" "api_cv_case_events_policy_doc" {
  statement {
    actions   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [
      module.cv_case_events.queue_arn,
      module.cv_case_events_dlq.queue_arn
    ]
  }
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [module.dynamodb_processed_events.table_arn]
  }
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "${module.prod_cv_case_events_log_group.log_group_arn}:*"
    ]
  }
}

module "iam_api_cv_case_events_policy" {
  source      = "../../../../modules/aws/iam_policy"
  name        = "prod-api-cv-case-events-policy"
  role_name   = module.iam_ecs_task_execution_role.role_name
  is_inline   = false
  policy      = data.aws_iam_policy_document.api_cv_case_events_policy_doc.json
  environment = var.environment
  project     = var.project
}

module "ecs_cv_case_events_service" {
  source                       = "../../../../modules/aws/ecs_service"
  service_name                 = "Prod-CvCaseEvents"
  family                       = "prod-cv-case-events"
  cluster_arn                  = module.ecs_cluster.cluster_arn
  cpu                          = "256"
  memory                       = "512"
  execution_role_arn           = module.iam_ecs_task_execution_role.role_arn
  task_role_arn                = module.iam_ecs_task_execution_role.role_arn
  desired_count                = 1
  platform_version             = "LATEST"
  launch_type                  = var.ecs_launch_type

  subnet_ids         = [module.subnets.private_subnet_ids["private3"], module.subnets.private_subnet_ids["private4"]]
  security_group_ids = [module.prod_worker_sg.security_group_id]
  assign_public_ip   = true

  container_definitions = jsonencode([{
    name      = "cv-case-events-worker"
    image     = "${module.ecr_prod_cv_case_events.repository_url}:latest"
    cpu       = 256
    memory    = 512
    essential = true
    command   = ["python", "-m", "altrx_backend.worker", "cv-case-events-worker"]
    environmentFiles = [{
      value = "arn:aws:s3:::${var.environment}-${lower(var.project)}-v3-uploads/backend-env/backend.env"
      type  = "s3"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = module.prod_cv_case_events_log_group.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "cv-case-events"
      }
    }
  }])

  enable_circuit_breaker = true
  capacity_providers = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 0
    }
  ]

  environment = var.environment
  project     = var.project
}

# =============================================================
# SNS Topic & CloudWatch Alarms for cv-case-events
# =============================================================
resource "aws_sns_topic" "prod_alerts" {
  name = "prod-alerts"
  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_cloudwatch_metric_alarm" "cv_case_events_dlq_depth" {
  alarm_name          = "${var.environment}-cv-case-events-dlq-depth"
  alarm_description   = "DLQ depth > 0 for cv-case-events-dlq.fifo"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.prod_alerts.arn]

  dimensions = {
    QueueName = module.cv_case_events_dlq.queue_name
  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_cloudwatch_metric_alarm" "cv_case_events_backlog" {
  alarm_name          = "${var.environment}-cv-case-events-backlog"
  alarm_description   = "SQS backlog age > 30 minutes for cv-case-events.fifo"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1800
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.prod_alerts.arn]

  dimensions = {
    QueueName = module.cv_case_events.queue_name
  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_cloudwatch_log_metric_filter" "cv_case_events_cio_failed" {
  name           = "${var.environment}-cv-case-events-cio-failed"
  pattern        = "cv_case_events.cio_failed"
  log_group_name = module.prod_cv_case_events_log_group.log_group_name

  metric_transformation {
    name          = "CvCaseEventsCioFailed"
    namespace     = "ALTRX/Worker"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "cv_case_events_cio_failed" {
  alarm_name          = "${var.environment}-cv-case-events-cio-failed"
  alarm_description   = "Log metric alarm for cv_case_events.cio_failed occurrences"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CvCaseEventsCioFailed"
  namespace           = "ALTRX/Worker"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.prod_alerts.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_cloudwatch_log_metric_filter" "carevalidate_webhook_invalid_signature" {
  name           = "${var.environment}-carevalidate-webhook-invalid-signature"
  pattern        = "carevalidate.webhook.invalid_signature"
  log_group_name = aws_cloudwatch_log_group.prod_backend.name

  metric_transformation {
    name          = "CareValidateWebhookInvalidSignature"
    namespace     = "ALTRX/API"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "carevalidate_webhook_invalid_signature" {
  alarm_name          = "${var.environment}-carevalidate-webhook-invalid-signature"
  alarm_description   = "Log metric alarm for carevalidate.webhook.invalid_signature occurrences"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CareValidateWebhookInvalidSignature"
  namespace           = "ALTRX/API"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.prod_alerts.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}



