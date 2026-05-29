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


# =============================================================
# Isolated Security Groups for Production
# =============================================================

module "prod_redis_sg" {
  source      = "../../../../modules/security_groups"
  name        = "redis"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  name_override = "Prod-Redis-Sg"
  description = "Allows Redis traffic"

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
  source      = "../../../../modules/security_groups"
  name        = "alb"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  name_override = "Prod-ALB-SG"
  description = "It allows internet traffic"

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
  source      = "../../../../modules/security_groups"
  name        = "be"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  name_override = "Prod-BE-SG"
  description = "Allow ALB Traffic"

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
  source      = "../../../../modules/security_groups"
  name        = "worker"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  name_override = "Worker-SG"
  description = "Allow Outbound and Inbound specific"

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
  source      = "../../../../modules/security_groups"
  name        = "wordpress"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  name_override = "wordpress-sg"
  description = "launch-wizard-1 created 2026-04-20T18:09:51.774Z"

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
  source                     = "../../../../modules/elasticache"
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
  source       = "../../../../modules/dynamodb"
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
  source       = "../../../../modules/dynamodb"
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
  source       = "../../../../modules/dynamodb"
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
  source       = "../../../../modules/dynamodb"
  name         = "production_altrx-checkout-submissions"
  hash_key     = "submission_token"
  billing_mode = "PAY_PER_REQUEST"
  deletion_protection_enabled = true
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

module "prod_target_group" {
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
  name_override        = "Prod-Backend"
}

module "prod_alb" {
  source               = "../../../../modules/alb"
  name                 = "alb"
  internal             = false
  security_group_ids   = [module.prod_alb_sg.security_group_id]
  subnet_ids           = [module.subnets.public_subnet_ids["public2"], module.subnets.public_subnet_ids["public1"]]
  enable_deletion_protection = false
  idle_timeout         = 60
  enable_http2         = true
  http_port            = 80
  http_default_action  = "redirect_to_https"
  https_port           = 443
  certificate_arn      = "arn:aws:acm:us-east-1:692137657276:certificate/33647a6f-f1c6-4ae8-aa6e-a58602892404"
  https_target_group_arn = module.prod_target_group.target_group_arn
  ssl_policy           = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  environment          = var.environment
  project              = var.project
  name_override        = "Prod-ALB"
}


# =============================================================
# Consolidated SQS Queues
# =============================================================

module "prod_payment_events_dlq" {
  source                     = "../../../../modules/sqs"
  name                       = "payment-events-dlq"
  environment                = var.environment
  project                    = var.project
  name_override              = "production_altrx-payment-events-dlq"
  visibility_timeout_seconds = 30
  message_retention_seconds   = 1209600
  max_message_size            = 262144
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
}

module "prod_payment_events" {
  source                     = "../../../../modules/sqs"
  name                       = "payment-events"
  environment                = var.environment
  project                    = var.project
  name_override              = "production_altrx-payment-events"
  visibility_timeout_seconds = 30
  message_retention_seconds   = 345600
  max_message_size            = 262144
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
  dlq_arn                    = module.prod_payment_events_dlq.queue_arn
  max_receive_count          = 5
  policy                     = jsonencode({
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
  source                     = "../../../../modules/sqs"
  name                       = "reconciler-trigger-dlq"
  environment                = var.environment
  project                    = var.project
  name_override              = "altrx-reconciler-trigger-dlq"
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
      Resource = "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger-dlq"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
}

module "prod_reconciler_trigger" {
  source                     = "../../../../modules/sqs"
  name                       = "reconciler-trigger"
  environment                = var.environment
  project                    = var.project
  name_override              = "altrx-reconciler-trigger"
  visibility_timeout_seconds = 660
  message_retention_seconds   = 345600
  max_message_size            = 262144
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
  dlq_arn                    = module.prod_reconciler_trigger_dlq.queue_arn
  max_receive_count          = 5
  policy                     = jsonencode({
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

resource "aws_cloudwatch_log_group" "amplify" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/aws/amplify/dsx3g35brvnhn"
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

resource "aws_iam_policy" "custom_user_vishal_ai_policy" {
  description = null
  name        = "custom_user_vishal_AI"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = ["cloudshell:*", "dynamodb:*", "sqs:*", "sts:GetCallerIdentity", "ec2:Describe*", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroup*", "ec2:RevokeSecurityGroup*", "ec2:CreateTags", "ecs:*", "application-autoscaling:*", "cloudwatch:*", "logs:DescribeLogGroups", "logs:DescribeLogStreams", "iam:ListRoles", "iam:GetUser", "iam:GetPolicy", "iam:GetPolicyVersion", "ecr:GetAuthorizationToken", "secretsmanager:ListSecrets", "amplify:ListApps", "amplify:GetApp"]
      Effect   = "Allow"
      Resource = "*"
      Sid      = "BaseAndAmplify"
      }, {
      Action   = "amplify:*"
      Effect   = "Allow"
      Resource = ["arn:aws:amplify:*:692137657276:apps/d1afdsckfq42or", "arn:aws:amplify:*:692137657276:apps/d1afdsckfq42or/*", "arn:aws:amplify:*:692137657276:apps/d9m305ipl0ufl", "arn:aws:amplify:*:692137657276:apps/d9m305ipl0ufl/*", "arn:aws:amplify:*:692137657276:apps/d1onpspxsudhmw", "arn:aws:amplify:*:692137657276:apps/d1onpspxsudhmw/*"]
      Sid      = "AmplifyApps"
      }, {
      Action   = "logs:*"
      Effect   = "Allow"
      Resource = ["arn:aws:logs:*:692137657276:log-group:/aws/amplify/*", "arn:aws:logs:*:692137657276:log-group:/aws/amplify/*:*", "arn:aws:logs:*:692137657276:log-group:/aws/ecs/*altrx*", "arn:aws:logs:*:692137657276:log-group:/aws/ecs/*altrx*:*", "arn:aws:logs:*:692137657276:log-group:*altrx*", "arn:aws:logs:*:692137657276:log-group:*altrx*:*"]
      Sid      = "AmplifyAndAltrxLogs"
      }, {
      Action   = "ecr:*"
      Effect   = "Allow"
      Resource = ["arn:aws:ecr:*:692137657276:repository/altrx-*", "arn:aws:ecr:*:692137657276:repository/staging_altrx-*", "arn:aws:ecr:*:692137657276:repository/preprod_altrx-*"]
      Sid      = "ECR"
      }, {
      Action   = ["secretsmanager:CreateSecret", "secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:UpdateSecret", "secretsmanager:PutSecretValue", "secretsmanager:DeleteSecret", "secretsmanager:RestoreSecret", "secretsmanager:TagResource", "secretsmanager:UntagResource", "secretsmanager:ListSecretVersionIds", "secretsmanager:GetResourcePolicy"]
      Effect   = "Allow"
      Resource = ["arn:aws:secretsmanager:*:692137657276:secret:altrx/*", "arn:aws:secretsmanager:*:692137657276:secret:staging_altrx/*", "arn:aws:secretsmanager:*:692137657276:secret:preprod_altrx/*"]
      Sid      = "SecretsManagerAltrx"
      }, {
      Action   = ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies", "iam:TagRole", "iam:UntagRole"]
      Effect   = "Allow"
      Resource = ["arn:aws:iam::692137657276:role/altrx-*", "arn:aws:iam::692137657276:role/staging_altrx-*", "arn:aws:iam::692137657276:role/preprod_altrx-*"]
      Sid      = "IAMManageAltrxRoles"
      }, {
      Action = "iam:PassRole"
      Condition = {
        StringEquals = {
          "iam:PassedToService" = ["ecs-tasks.amazonaws.com", "amplify.amazonaws.com", "application-autoscaling.amazonaws.com"]
        }
      }
      Effect   = "Allow"
      Resource = ["arn:aws:iam::692137657276:role/altrx-*", "arn:aws:iam::692137657276:role/staging_altrx-*", "arn:aws:iam::692137657276:role/preprod_altrx-*", "arn:aws:iam::692137657276:role/service-role/AmplifySSRLoggingRole-*"]
      Sid      = "PassRoleScoped"
      }, {
      Action = "iam:CreateServiceLinkedRole"
      Condition = {
        StringEquals = {
          "iam:AWSServiceName" = ["ecs.amazonaws.com", "application-autoscaling.amazonaws.com", "ecs.application-autoscaling.amazonaws.com"]
        }
      }
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ServiceLinkedRoles"
      }, {
      Action   = "ecr:GetAuthorizationToken"
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ECRAuth"
      }, {
      Action   = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"]
      Effect   = "Allow"
      Resource = ["arn:aws:ecr:us-east-1:692137657276:repository/prod-backend", "arn:aws:ecr:us-east-1:692137657276:repository/preprod-backend"]
      Sid      = "ECRPush"
      }, {
      Action   = ["ecs:UpdateService", "ecs:DescribeServices", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ECSDeploy"
      }, {
      Action = "iam:PassRole"
      Condition = {
        StringLike = {
          "iam:PassedToService" = "ecs-tasks.amazonaws.com"
        }
      }
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ECSPassRole"
    }]
    Version = "2012-10-17"
  })
  tags     = {}
  tags_all = {}
}

resource "aws_iam_policy" "amplify_ssr_logging_policy" {
  description = null
  name        = "AmplifySSRLoggingPolicy-638507c3-6940-4947-b58d-16f5ca25c35a"
  path        = "/service-role/"
  policy = jsonencode({
    Statement = [{
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Effect   = "Allow"
      Resource = "arn:aws:logs:us-east-1:692137657276:log-group:/aws/amplify/*:log-stream:*"
      Sid      = "PushLogs"
      }, {
      Action   = "logs:CreateLogGroup"
      Effect   = "Allow"
      Resource = "arn:aws:logs:us-east-1:692137657276:log-group:/aws/amplify/*"
      Sid      = "CreateLogGroup"
      }, {
      Action   = "logs:DescribeLogGroups"
      Effect   = "Allow"
      Resource = "arn:aws:logs:us-east-1:692137657276:log-group:*"
      Sid      = "DescribeLogGroups"
    }]
    Version = "2012-10-17"
  })
  tags     = {}
  tags_all = {}
}

module "iam_ecs_task_execution_role" {
  source             = "../../../../modules/iam_role"
  name               = "ECS-Task-execution-role"
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

module "iam_altrx_ssm_role" {
  source             = "../../../../modules/iam_role"
  name               = "altrx_ssm_role"
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

resource "aws_iam_policy" "custom_s3_vishal_ai_policy" {
  description = null
  name        = "Custom_S3_Vishal_ai"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = ["s3:PutBucketCORS", "s3:GetBucketCORS"]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::production-altrx-v3-uploads"
      }, {
      Action   = ["s3:PutObject", "s3:PutObjectAcl"]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::production-altrx-v3-uploads/worker-env/worker.env"
      Sid      = "WriteWorkerEnv"
      }, {
      Action   = ["ecs:UpdateService"]
      Effect   = "Allow"
      Resource = "arn:aws:ecs:us-east-1:692137657276:service/Prod-Altrx/Prod-Worker"
      Sid      = "RestartWorker"
      }, {
      Action   = ["sqs:StartMessageMoveTask", "sqs:ListMessageMoveTasks"]
      Effect   = "Allow"
      Resource = ["arn:aws:sqs:us-east-1:692137657276:production_altrx-payment-events", "arn:aws:sqs:us-east-1:692137657276:production_altrx-payment-events-dlq"]
      Sid      = "DrainDLQ"
      }, {
      Action   = ["s3:CreateBucket", "s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock", "s3:PutEncryptionConfiguration", "s3:GetEncryptionConfiguration", "s3:PutBucketCORS", "s3:GetBucketCORS", "s3:PutLifecycleConfiguration", "s3:GetLifecycleConfiguration", "s3:PutBucketTagging", "s3:GetBucketTagging", "s3:GetBucketLocation", "s3:ListBucket"]
      Effect   = "Allow"
      Resource = ["arn:aws:s3:::staging-altrx-v3-uploads", "arn:aws:s3:::preprod-altrx-v3-uploads"]
      Sid      = "ProvisionAltrxV3UploadBuckets"
      }, {
      Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
      Effect   = "Allow"
      Resource = ["arn:aws:s3:::staging-altrx-v3-uploads/v3/pen-uploads/*", "arn:aws:s3:::preprod-altrx-v3-uploads/v3/pen-uploads/*"]
      Sid      = "SmokeTestObjectsInAltrxV3UploadBuckets"
      }, {
      Action = "lambda:ListFunctions"
      Condition = {
        StringEquals = {
          "aws:RequestedRegion" = "us-east-1"
        }
      }
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ListLambdaInUsEast1Only"
      }, {
      Action   = "lambda:GetFunctionConfiguration"
      Effect   = "Allow"
      Resource = ["arn:aws:lambda:us-east-1:692137657276:function:amplify-d9m305ipl0ufl-*", "arn:aws:lambda:us-east-1:692137657276:function:amplify-d1onpspxsudhmw-*"]
      Sid      = "ReadAmplifySSRFunctionConfig"
    }]
    Version = "2012-10-17"
  })
  tags     = {}
  tags_all = {}
}

module "iam_amplify_ssr_logging_role" {
  source             = "../../../../modules/iam_role"
  name               = "AmplifySSRLoggingRole-638507c3-6940-4947-b58d-16f5ca25c35a"
  path               = "/service-role/"
  environment        = var.environment
  project            = var.project
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "amplify.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  policy_arns = [
    aws_iam_policy.amplify_ssr_logging_policy.arn
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
      Resource = ["arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-checkout-submissions", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-checkout-submissions/index/*", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-stripe-customers", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-stripe-customers/index/*", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-processed-events", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-events-log", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-events-log/index/*"]
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
  source               = "../../../../modules/ecr"
  name                 = "worker"
  environment          = var.environment
  project              = var.project
  name_override        = "prod-worker"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
}

module "ecs_cluster" {
  source                    = "../../../../modules/ecs_cluster"
  cluster_name              = "Prod-Altrx"
  enable_container_insights = true
  environment               = var.environment
  project                   = var.project
}

module "ecs_backend_service" {
  source                       = "../../../../modules/ecs_service"
  service_name                 = "Prod-Backend"
  family                       = "prod-backend"
  cluster_arn                  = module.ecs_cluster.cluster_arn
  cpu                          = "256"
  memory                       = "512"
  execution_role_arn           = module.iam_ecs_task_execution_role.role_arn
  task_role_arn                = module.iam_ecs_task_execution_role.role_arn
  desired_count                = 1
  platform_version             = "1.4.0"
  launch_type                  = var.ecs_launch_type
  task_definition_arn_override = "prod-backend:11"

  subnet_ids          = [module.subnets.private_subnet_ids["private3"], module.subnets.private_subnet_ids["private4"]]
  security_group_ids  = [module.prod_be_sg.security_group_id]
  assign_public_ip    = false

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
  source                     = "../../../../modules/lambda"
  function_name              = "reconciler"
  environment                = var.environment
  project                    = var.project
  name_override              = "altrx-reconciler"
  role_name_override         = "AltrxReconcilerLambdaRole"
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
  name_override        = "altrx-reconciler"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
}

module "ecs_worker_service" {
  source                       = "../../../../modules/ecs_service"
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
  task_definition_arn_override = "Prod-Worker-Payment:4"

  subnet_ids          = [module.subnets.private_subnet_ids["private3"], module.subnets.private_subnet_ids["private4"]]
  security_group_ids  = [module.prod_worker_sg.security_group_id]
  assign_public_ip    = true

  container_definitions = jsonencode([{
    name      = "worker-payment"
    image     = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
    cpu       = 256
    memory    = 512
    essential = true
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
  source               = "../../../../modules/ecr"
  name                 = "backend"
  environment          = var.environment
  project              = var.project
  name_override        = "prod-backend"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
}

resource "aws_amplify_app" "production" {
  access_token                  = null # sensitive
  auto_branch_creation_patterns = []
  basic_auth_credentials        = null # sensitive
  build_spec                    = "version: 1\nfrontend:\n  phases:\n    preBuild:\n      commands:\n        - nvm use 20  # Use Node.js v20 as required by vite-builder\n        - npm ci\n    build:\n      commands:\n        - npx nuxi build\n  artifacts:\n    baseDirectory: .output\n    files:\n      - '**/*'\n  cache:\n    paths:\n      - node_modules/**/*"
  compute_role_arn              = null
  description                   = null
  enable_auto_branch_creation   = false
  enable_basic_auth             = false
  enable_branch_auto_build      = false
  enable_branch_auto_deletion   = false
  environment_variables = {
    APP_ENV                                = "production"
    ATTENTIVE_API_SECRET                   = "N0x4TkpNTTdnY1JxMFdxc3R2UnZ3S2NQalVSQ3Nya2VPQTBa"
    ATTENTIVE_SIGNUP_SOURCE_ID             = "1341729"
    BLOCKED_AFFIDS                         = "58"
    CAPI_CSRF_SECRET                       = "5d2cffa569ca17d687182f16af1ebadcfc52ea1727b559840773c202b6d87ee6"
    CAPI_PURCHASE_STRICT_MODE              = "true"
    CAREVALIDATE_WEBHOOK_SECRET            = "45645ee941c7e9c1c268e9d0b9fc06a99504e7f9b1ffee545e138c6abbc09ae4"
    CARE_VALIDATE_API_KEY_PROD             = "+o1jxQMfvrAiR91JGD5fl7F8gnVfjtGPCvWwvzOAB5Y="
    CARE_VALIDATE_API_KEY_STAGING          = "khwPiLCQQFlwtMmFmq2UETx7mNUP1w1sM1GpX6U+8OU="
    CARE_VALIDATE_API_URL_PROD             = "https://api.care360-next.carevalidate.com/api/v1/dynamic-case"
    CARE_VALIDATE_API_URL_STAGING          = "https://api-staging.care360-next.carevalidate.com/api/v1/dynamic-case"
    GLUCA_NEW_SEMA_01                      = "Glucasema1"
    GLUCA_NEW_SEMA_03                      = "Glucasema3"
    GLUCA_NEW_SEMA_06                      = "Glucasema6"
    GLUCA_NEW_SEMA_12                      = "Glucasema12"
    GLUCA_NEW_TIRZ_01                      = "GlucaTirz1"
    GLUCA_NEW_TIRZ_03                      = "GlucaTirz3"
    GLUCA_NEW_TIRZ_06                      = "GlucaTirz6"
    GLUCA_NEW_TIRZ_12                      = "GlucaTirz12"
    GLUCA_SEMA_03                          = "glucasema03"
    GLUCA_SEMA_06                          = "glucasema06"
    GLUCA_SEMA_12                          = "glucasema12"
    GLUCA_TIRZ_03                          = "glucatirz03"
    GLUCA_TIRZ_06                          = "glucatirz06"
    GLUCA_TIRZ_12                          = "glucatirz12"
    MEMORIAL_OFFER_ENABLED                 = "false"
    NODE_ENV                               = "production"
    NORTHBEAM_API_KEY_PROD                 = "88b8b757-14f3-46e9-ac7a-1f5f23f23699"
    NORTHBEAM_CLIENT_ID_PROD               = "84aeb136-c685-4f16-b6ba-8cdb2bf95cb1"
    NUXT_AC_API_KEY                        = "cbaee37b274fd99e7e653445e85f723c5daa48dd16b33041ff45829f601e80ccf829c667"
    NUXT_AC_API_URL                        = "https://altrx.api-us1.com"
    NUXT_FACEBOOK_ACCESS_TOKEN             = "EAARQxZAZBji0sBQh5AY47GPTT6vUmw7js9DZAnxeZCRjzkTziZANSPMFODZBBHQSlALYhzZBIYk8cXPLmLlDA1BKt6GL1xGo6HmZBAwLjHW9TbdZBz8c1Yw4XRF6i8ZBwQ3iKtEyNZC0pUlUbn7p9ZAVoaEjD5LZAwqPINd04u0kxf2ZACs1QY6O4OiPtGF2SGJPsxMq6X1gZDZD"
    NUXT_FACEBOOK_CLIENT_ACCESS_TOKEN      = "EAAWVvKkgHHsBQpaa82iE0e4aunfc3uiZAIKFWUZBDiZAGwHSn1XbN4oG5EreMV5ZCcxdZANgzAjTtBqXZCrKG42fnHJMt4LETL3kHmZAhdHdvIP6s1EXLHxwZByhnZCROTpGAZBGZAB70jS6gS4XgOrdUExPYUZCTik85Yes54zrzPVjBVw5KYFb5nuxfcOK8Hf0NQZDZD"
    NUXT_PUBLIC_BACKEND_BASE_URL           = "https://api.altrx.com"
    NUXT_PUBLIC_CUSTOMERIO_WRITE_KEY       = "74db6f5e8e91bec96fc1"
    NUXT_PUBLIC_EF_API_KEY                 = "BwtATVAWTzqgE5uuSljvvg"
    NUXT_PUBLIC_EF_BASE_URL                = "https://api.eflow.team/v1"
    NUXT_PUBLIC_FINGERPRINT_API_KEY        = "906b730d0b25ae8e2af1fefec8a3ef3c"
    NUXT_PUBLIC_OFFER_END_DATETIME         = "2026-05-31T04:00:00Z"
    NUXT_PUBLIC_ORGANIZATION_ID            = "f3c75a6e-bf79-4b14-9829-770f9f82763e"
    NUXT_PUBLIC_SENTRY_DSN                 = "https://20734d967249f18b0aa8c8eec466a528@o4506247411400704.ingest.us.sentry.io/4510974156603393"
    NUXT_PUBLIC_SUPABASE_URL               = "https://bajpgkwpuhebwdrokrcg.supabase.co"
    NUXT_TIKTOK_API_KEY                    = "79143f1c9f28a86b70a4277d6a13f882544a87cb"
    PAYPAL_CLIENT_ID_LIVE                  = "AW9U7PgwtQyIJgJcSAGWc12VWsUME6arNvyZ6VYE37hzBOfTtNqwQErclnma2INar0ZxnQoIQxj5at59"
    PAYPAL_CLIENT_ID_SANDBOX               = "AfAvWvaJf7jJPd0sWe9JRBP-dPv_vIivhfrCs7ghwmXu8g4P_otGykiqkqyVvLBGGrdQN48jMhz2Ozq3"
    PAYPAL_SECRET_KEY_LIVE                 = "ECIDQdCq-DTjpODdqWCQ5saGGor0aXz03TqZBh9cbTQOPqjDonPCCAo9pYef_x5VBrFuplv-2pImggZh"
    PAYPAL_SECRET_KEY_SANDBOX              = "EB2VX-sIWtMLiWVYq7DqqEhCfpQqw9Z2AhztS1k00WrVL1tcsgBoF6PN9W7xWH50NY6LizFkSuW6xYDp"
    SEMAGLUTIDE_12_MONTH_CODE              = "THRIVE12"
    SEMAGLUTIDE_1_MONTH_CODE               = "THRIVE01"
    SEMAGLUTIDE_3_MONTH_CODE               = "THRIVE03"
    SEMAGLUTIDE_6_MONTH_CODE               = "THRIVE06"
    SPECIAL_SMS_10_CODE                    = "SPECIAL_SMS_10_CODE=SPECIALSMS10"
    SPECIAL_SMS_20_CODE                    = "SPECIALSMS20"
    SPRING_OFFER_ENABLED                   = "true"
    STRIPE_PUBLISHABLE_KEY_PROD            = "pk_live_51HqSIiKAXrtjbq2dtXcGLkFqhqPquraau6jRB8nDCrDVIGj7me2ZEAiQxZNwuG9A7Y1Gzn6vg8xslQuCpoTByMKd00cmPemstt"
    STRIPE_PUBLISHABLE_KEY_STAGING         = "pk_test_51HqSIiKAXrtjbq2dUipJMaSqisS96Auqj0wFVcuuwtD75gC0Jof2HIlmG8RoGYLlAToyPeIDOqMsjTLUfgXLNh1U00lrHRJ5Bl"
    SUPABASE_ANON_KEY                      = "sb_publishable_Pi-WGAF8RF2pUHnBmhuWUQ_E6sjjwQc"
    TELLESCOPE_STRIPE_PUBLISHABLE_KEY_LIVE = "pk_live_51TM96P5wzaB24K2YuMY0hPOSvzVvnZqyK1EAtTitBxovNcm3aMdHOZy2BFqe1gKR7sN2Hz7iqBEYS7lJxPK6jfyq00U4nE8MRc"
    TIRZEPATIDE_12_MONTH_CODE              = "BREAKTHRU12"
    TIRZEPATIDE_1_MONTH_CODE               = "BREAKTHRU01"
    TIRZEPATIDE_3_MONTH_CODE               = "BREAKTHRU03"
    TIRZEPATIDE_6_MONTH_CODE               = "BREAKTHRU06"
    UGC2026DEAL                            = "ugc2026deal"
    V9_SAVE_10_CODE                        = "V9SAVE10"
    V9_SAVE_15_CODE                        = "V9SAVE15"
    V9_SAVE_20_CODE                        = "V9SAVE20"
    WEB3FORMS_ACCESS_KEY                   = "bcd12197-4ec8-4054-924b-a6bd997589ae"
    WHITECOAT_STRIPE_PUBLISHABLE_KEY_LIVE  = "pk_live_51TUTcZ92ycriP3hHApoRlDsqYSUimlEH84ydRDNjpCIrAuQnm3jwwpkX6sberJyX4MHZf1nCxnlkPFPfUjKG4cnM00wunwcvHZ"
  }
  iam_service_role_arn = "arn:aws:iam::692137657276:role/service-role/AmplifySSRLoggingRole-638507c3-6940-4947-b58d-16f5ca25c35a"
  name                 = "Production_Altrx"
  oauth_token          = null # sensitive
  platform             = "WEB_COMPUTE"
  repository           = "https://github.com/trinity-healthcare-supply/altrx"
  tags                 = {}
  tags_all             = {}
  cache_config {
    type = "AMPLIFY_MANAGED_NO_COOKIES"
  }
  custom_rule {
    condition = null
    source    = "https://altrx.com"
    status    = "302"
    target    = "https://www.altrx.com"
  }
  custom_rule {
    condition = null
    source    = "/blogs"
    status    = "200"
    target    = "https://blogs.altrx.com"
  }
  custom_rule {
    condition = null
    source    = "/blogs/<*>"
    status    = "200"
    target    = "https://blogs.altrx.com/<*>"
  }
  custom_rule {
    condition = null
    source    = "/<*>"
    status    = "404-200"
    target    = "/index.html"
  }
}
