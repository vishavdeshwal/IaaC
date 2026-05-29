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
        key          = "altrx/preprod/terraform.tfstate"
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
# Isolated Security Groups for Preprod
# =============================================================
module "preprod_redis_sg" {
  source      = "../../../../modules/security_groups"
  name        = "redis"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  description = "Allows Redis traffic"

  ingress_rules = [{
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    cidr_blocks     = []
    security_groups = [module.preprod_be_sg.security_group_id]
    description     = "Allows Redis traffic from Backend"
  }]

  egress_rules = [{
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = "Allows Redis traffic"
  }]
}

module "preprod_alb_sg" {
  source      = "../../../../modules/security_groups"
  name        = "alb"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  description = "It allows internet traffic"

  ingress_rules = [{
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = "It allows internet traffic"
    }, {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = "It allows internet traffic"
  }]

  egress_rules = [{
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = "Allows all outbound traffic"
  }]
}

module "preprod_be_sg" {
  source      = "../../../../modules/security_groups"
  name        = "be"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  description = "Allow ALB Traffic"

  ingress_rules = [{
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    cidr_blocks     = []
    security_groups = [module.preprod_alb_sg.security_group_id]
    description     = "Allow ALB Traffic"
  }]

  egress_rules = [{
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = "Allows all outbound traffic"
  }]
}

module "preprod_worker_sg" {
  source      = "../../../../modules/security_groups"
  name        = "worker"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  description = "Allow Outbound and Inbound specific"

  ingress_rules = []

  egress_rules = [{
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = "Allow Outbound and Inbound specific"
  }]
}

module "preprod_wordpress_sg" {
  source      = "../../../../modules/security_groups"
  name        = "wordpress"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  description = "Allows HTTP/HTTPS and SSH access"

  ingress_rules = [{
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = "Allow SSH"
    }, {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = "Allow HTTPS"
    }, {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = "Allow HTTP"
  }]

  egress_rules = [{
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
    description     = "Allows all outbound traffic"
  }]
}

# =============================================================
# Consolidated Databases (DynamoDB & Redis)
# =============================================================
module "preprod_redis" {
  source                     = "../../../../modules/elasticache"
  name                       = "redis"
  engine                     = "redis"
  node_type                  = "cache.t3.small"
  num_cache_clusters         = 1
  transit_encryption         = true
  at_rest_encryption         = true
  auth_token                 = null
  maintenance_window         = "thu:04:00-thu:05:00"
  snapshot_retention_limit   = 1
  snapshot_window            = "06:30-07:30"
  subnet_ids                 = [module.subnets.private_subnet_ids["private1"], module.subnets.private_subnet_ids["private2"]]
  security_group_ids         = [module.preprod_redis_sg.security_group_id]
  environment                = var.environment
  project                    = var.project
  apply_immediately          = true
}

module "dynamodb_payment_events_log" {
  source       = "../../../../modules/dynamodb"
  name         = "${var.environment}_${lower(var.project)}-payment-events-log"
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
  source       = "../../../../modules/dynamodb"
  name         = "${var.environment}_${lower(var.project)}-processed-events"
  hash_key     = "event_id"
  billing_mode = "PAY_PER_REQUEST"
  environment  = var.environment
  project      = var.project
  attributes = [
    { name = "event_id", type = "S" }
  ]
}

module "dynamodb_stripe_customers" {
  source       = "../../../../modules/dynamodb"
  name         = "${var.environment}_${lower(var.project)}-stripe-customers"
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
  source       = "../../../../modules/dynamodb"
  name         = "${var.environment}_${lower(var.project)}-checkout-submissions"
  hash_key     = "submission_token"
  billing_mode = "PAY_PER_REQUEST"
  environment  = var.environment
  project      = var.project
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

# =============================================================
# Consolidated Load Balancing (ALB, Listeners, Target Groups)
# =============================================================
module "preprod_target_group" {
  source               = "../../../../modules/target_group"
  name                 = "backend"
  port                 = 8000
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  deregistration_delay = 300
  health_check_path    = "/healthz"
  health_check_protocol = "HTTP"
  health_check_port    = "traffic-port"
  health_check_interval = 30
  health_check_timeout = 5
  healthy_threshold   = 5
  unhealthy_threshold = 2
  health_check_matcher = "200"
  environment          = var.environment
  project              = var.project
  name_override        = "${title(var.environment)}-Backend"
}

module "preprod_alb" {
  source               = "../../../../modules/alb"
  name                 = "alb"
  internal             = false
  security_group_ids   = [module.preprod_alb_sg.security_group_id]
  subnet_ids           = [module.subnets.public_subnet_ids["public1"], module.subnets.public_subnet_ids["public2"]]
  enable_deletion_protection = false
  idle_timeout         = 60
  enable_http2         = true
  http_port            = 80
  http_default_action  = "redirect_to_https"
  https_port           = 443
  certificate_arn      = "arn:aws:acm:us-east-1:692137657276:certificate/33647a6f-f1c6-4ae8-aa6e-a58602892404"
  https_target_group_arn = module.preprod_target_group.target_group_arn
  ssl_policy           = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  environment          = var.environment
  project              = var.project
  name_override        = "${title(var.environment)}-ALB"
}

# =============================================================
# Consolidated SQS Queues
# =============================================================
module "preprod_payment_events_dlq" {
  source                     = "../../../../modules/sqs"
  name                       = "payment-events-dlq"
  environment                = var.environment
  project                    = var.project
  name_override              = "${var.environment}_${lower(var.project)}-payment-events-dlq"
  visibility_timeout_seconds = 30
  message_retention_seconds   = 1209600
  max_message_size            = 262144
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
}

module "preprod_payment_events" {
  source                     = "../../../../modules/sqs"
  name                       = "payment-events"
  environment                = var.environment
  project                    = var.project
  name_override              = "${var.environment}_${lower(var.project)}-payment-events"
  visibility_timeout_seconds = 30
  message_retention_seconds   = 345600
  max_message_size            = 262144
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
  dlq_arn                    = module.preprod_payment_events_dlq.queue_arn
  max_receive_count          = 5
  policy                     = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:${var.environment}_${lower(var.project)}-payment-events"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
}

module "reconciler_trigger_dlq" {
  source                     = "../../../../modules/sqs"
  name                       = "reconciler-trigger-dlq"
  environment                = var.environment
  project                    = var.project
  name_override              = "${lower(var.project)}-reconciler-trigger-dlq-${var.environment}"
  visibility_timeout_seconds = 30
  message_retention_seconds   = 1209600
  max_message_size            = 262144
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
  policy                     = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:${lower(var.project)}-reconciler-trigger-dlq-${var.environment}"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
}

module "reconciler_trigger" {
  source                     = "../../../../modules/sqs"
  name                       = "reconciler-trigger"
  environment                = var.environment
  project                    = var.project
  name_override              = "${lower(var.project)}-reconciler-trigger-${var.environment}"
  visibility_timeout_seconds = 660
  message_retention_seconds   = 345600
  max_message_size            = 262144
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
  dlq_arn                    = module.reconciler_trigger_dlq.queue_arn
  max_receive_count          = 5
  policy                     = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:${lower(var.project)}-reconciler-trigger-${var.environment}"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
}

# =============================================================
# Consolidated CloudWatch Logging Groups
# =============================================================
module "preprod_worker_log_group" {
  source            = "../../../../modules/cloudwatch_log_group"
  name              = "/ecs/${var.environment}-worker"
  retention_in_days = 7
  tags = {
    Name        = "/ecs/${var.environment}-worker"
    Environment = var.environment
    Project     = var.project
  }
}

module "preprod_reconciler_log_group" {
  source            = "../../../../modules/cloudwatch_log_group"
  name              = "/aws/lambda/${lower(var.project)}-reconciler-${var.environment}"
  retention_in_days = 7
  tags = {
    Name        = "/aws/lambda/${lower(var.project)}-reconciler-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

module "preprod_redis_log_group" {
  source            = "../../../../modules/cloudwatch_log_group"
  name              = "redis-${var.environment}"
  retention_in_days = 7
  tags = {
    Name        = "redis-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

module "preprod_backend_log_group" {
  source            = "../../../../modules/cloudwatch_log_group"
  name              = "/ecs/${var.environment}-backend"
  retention_in_days = 7
  tags = {
    Name        = "/ecs/${var.environment}-backend"
    Environment = var.environment
    Project     = var.project
  }
}

module "preprod_ecs_performance_log_group" {
  source            = "../../../../modules/cloudwatch_log_group"
  name              = "/aws/ecs/containerinsights/${title(var.environment)}-${title(lower(var.project))}/performance"
  retention_in_days = 1
  tags = {
    Name        = "/aws/ecs/containerinsights/${title(var.environment)}-${title(lower(var.project))}/performance"
    Environment = var.environment
    Project     = var.project
  }
}

module "preprod_worker_payment_log_group" {
  source            = "../../../../modules/cloudwatch_log_group"
  name              = "/ecs/${title(var.environment)}-Worker-Payment"
  retention_in_days = 7
  tags = {
    Name        = "/ecs/${title(var.environment)}-Worker-Payment"
    Environment = var.environment
    Project     = var.project
  }
}

# =============================================================
# Consolidated IAM Roles & Policies (Fully Isolated Suffixes)
# =============================================================
resource "aws_iam_policy" "ecs_s3_env_policy" {
  name        = "${var.environment}-ecs-s3-env-policy"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = ["s3:GetObject"]
      Effect   = "Allow"
      Resource = [
        "arn:aws:s3:::${var.environment}-${lower(var.project)}-v3-uploads/worker-env/worker.env",
        "arn:aws:s3:::${var.environment}-${lower(var.project)}-v3-uploads/backend-env/backend.env"
      ]
      }, {
      Action   = ["s3:GetBucketLocation"]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::${var.environment}-${lower(var.project)}-v3-uploads"
    }]
    Version = "2012-10-17"
  })
}

module "iam_ecs_task_execution_role" {
  source             = "../../../../modules/iam_role"
  name               = "ECS-Task-execution-role-${var.environment}"
  environment        = var.environment
  project            = var.project
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
  name        = "${var.environment}-ecs-dynamodb-sqs-policy"
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
        "arn:aws:dynamodb:us-east-1:692137657276:table/${var.environment}_${lower(var.project)}-*",
        "arn:aws:dynamodb:us-east-1:692137657276:table/${var.environment}_${lower(var.project)}-*/index/*"
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
        "arn:aws:sqs:us-east-1:692137657276:${var.environment}_${lower(var.project)}-*",
        "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger-${var.environment}",
        "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger-dlq-${var.environment}"
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
  source             = "../../../../modules/iam_role"
  name               = "altrx_ssm_role_${var.environment}"
  environment        = var.environment
  project            = var.project
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
  name        = "AltrxReconcilerPolicy-${var.environment}"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:DescribeTable"]
      Effect   = "Allow"
      Resource = [
        "arn:aws:dynamodb:us-east-1:692137657276:table/${var.environment}_${lower(var.project)}-checkout-submissions",
        "arn:aws:dynamodb:us-east-1:692137657276:table/${var.environment}_${lower(var.project)}-checkout-submissions/index/*",
        "arn:aws:dynamodb:us-east-1:692137657276:table/${var.environment}_${lower(var.project)}-stripe-customers",
        "arn:aws:dynamodb:us-east-1:692137657276:table/${var.environment}_${lower(var.project)}-stripe-customers/index/*",
        "arn:aws:dynamodb:us-east-1:692137657276:table/${var.environment}_${lower(var.project)}-processed-events",
        "arn:aws:dynamodb:us-east-1:692137657276:table/${var.environment}_${lower(var.project)}-payment-events-log",
        "arn:aws:dynamodb:us-east-1:692137657276:table/${var.environment}_${lower(var.project)}-payment-events-log/index/*"
      ]
      Sid      = "DynamoDBAccess"
      }, {
      Action   = ["sqs:SendMessage"]
      Effect   = "Allow"
      Resource = module.reconciler_trigger.queue_arn
      Sid      = "SQSSelfChain"
      }, {
      Action   = ["secretsmanager:GetSecretValue"]
      Effect   = "Allow"
      Resource = "arn:aws:secretsmanager:us-east-1:692137657276:secret:${var.environment}_${lower(var.project)}/*"
      Sid      = "SecretsManagerAccess"
    }]
    Version = "2012-10-17"
  })
}

# =============================================================
# Consolidated Compute (ECS, Lambda, Amplify, ECR)
# =============================================================
module "ecr_preprod_worker" {
  source               = "../../../../modules/ecr"
  name                 = "worker"
  environment          = var.environment
  project              = var.project
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
}

module "ecs_cluster" {
  source                    = "../../../../modules/ecs_cluster"
  cluster_name              = "${title(var.environment)}-${title(var.project)}"
  enable_container_insights = false
  environment               = var.environment
  project                   = var.project
}

module "ecs_backend_service" {
  source             = "../../../../modules/ecs_service"
  service_name       = "${title(var.environment)}-Backend"
  family             = "${var.environment}-backend"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.iam_ecs_task_execution_role.role_arn
  task_role_arn      = module.iam_ecs_task_execution_role.role_arn
  desired_count      = 1
  platform_version   = "1.4.0"
  launch_type        = var.ecs_launch_type
  
  subnet_ids          = [module.subnets.private_subnet_ids["private1"], module.subnets.private_subnet_ids["private2"]]
  security_group_ids  = [module.preprod_be_sg.security_group_id]
  assign_public_ip    = false

  depends_on = [
    aws_iam_role_policy_attachment.ecs_s3_env_attachment,
    aws_iam_role_policy_attachment.ecs_dynamodb_sqs_attachment
  ]

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
    environmentFiles = [{
      value = "arn:aws:s3:::${var.environment}-${lower(var.project)}-v3-uploads/backend-env/backend.env"
      type  = "s3"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = module.preprod_backend_log_group.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])

  target_group_arn = module.preprod_target_group.target_group_arn
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
  source                     = "../../../../modules/lambda"
  function_name              = "reconciler"
  environment                = var.environment
  project                    = var.project
  image_uri                  = "692137657276.dkr.ecr.us-east-1.amazonaws.com/altrx-reconciler:v-26-05-1527"
  memory_size                = 512
  timeout                    = 600
  environment_variables      = var.reconciler_env_vars
  additional_policy_arns     = [aws_iam_policy.altrx_reconciler_policy.arn]
}

module "ecr_reconciler" {
  source               = "../../../../modules/ecr"
  name                 = "reconciler"
  environment          = var.environment
  project              = var.project
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
}

module "ecs_worker_service" {
  source             = "../../../../modules/ecs_service"
  service_name       = "${title(var.environment)}-Worker-Payment"
  family             = "${title(var.environment)}-Worker-Payment"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.iam_ecs_task_execution_role.role_arn
  task_role_arn      = module.iam_ecs_task_execution_role.role_arn
  desired_count      = 1
  platform_version   = "LATEST"
  launch_type        = var.ecs_launch_type
  
  subnet_ids          = [module.subnets.private_subnet_ids["private1"], module.subnets.private_subnet_ids["private2"]]
  security_group_ids  = [module.preprod_worker_sg.security_group_id]
  assign_public_ip    = true

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
      value = "arn:aws:s3:::${var.environment}-${lower(var.project)}-v3-uploads/worker-env/worker.env"
      type  = "s3"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = module.preprod_worker_payment_log_group.log_group_name
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

module "ecr_preprod_backend" {
  source               = "../../../../modules/ecr"
  name                 = "backend"
  environment          = var.environment
  project              = var.project
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
    allowed_methods = ["PUT"]
    allowed_origins = [
      "https://staging-ths.altrx.com",
      "https://staging.d1onpspxsudhmw.amplifyapp.com",
      "https://d1onpspxsudhmw.amplifyapp.com",
      "http://localhost:3000"
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}