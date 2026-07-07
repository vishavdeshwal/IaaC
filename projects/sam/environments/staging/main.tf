terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket       = "sammmm-terraform-state-847659"
    key          = "sam/staging/terraform.tfstate"
    region       = "ap-south-1"
    profile      = "sam"
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

module "eip" {
  source      = "../../../../modules/aws/eip"
  environment = var.environment
  project     = var.project
}

module "nat_gateway" {
  source            = "../../../../modules/aws/nat_gateway"
  eip_allocation_id = module.eip.eip_allocation_id
  public_subnet_id  = module.subnets.public_subnet_ids["public-1"]
  igw_dependency    = module.igw.igw_id
  environment       = var.environment
  project           = var.project
}

module "route_tables" {
  source         = "../../../../modules/aws/route_tables"
  vpc_id         = module.vpc.vpc_id
  igw_id         = module.igw.igw_id
  nat_gateway_id = module.nat_gateway.nat_gateway_id
  environment    = var.environment
  project        = var.project
}

module "route_table_association" {
  source                 = "../../../../modules/aws/route_table_association"
  public_subnet_ids      = module.subnets.public_subnet_ids
  private_subnet_ids     = module.subnets.private_subnet_ids
  public_route_table_id  = module.route_tables.public_route_table_id
  private_route_table_id = module.route_tables.private_route_table_id
}


// --------- Security Groups ------------------
module "alb_sg" {
  source      = "../../../../modules/aws/security_groups"
  name        = "abl"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow HTTP traffic"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow HTTPS traffic"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 8443
      to_port     = 8443
      protocol    = "tcp"
      description = "Allow HTTPS dashboard traffic"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = ""
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "app_sg" {
  source      = "../../../../modules/aws/security_groups"
  name        = "app"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      description = "Allow frontend traffic from ALB"
      cidr_blocks = []
      security_groups = [
        module.alb_sg.security_group_id
      ]
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Allow traffic from ALB"
      cidr_blocks = []
      security_groups = [
        module.alb_sg.security_group_id
      ]
    },
    {
      from_port   = 8091
      to_port     = 8091
      protocol    = "tcp"
      description = "Allow dashboard traffic from ALB"
      cidr_blocks = []
      security_groups = [
        module.alb_sg.security_group_id
      ]
    }
  ]

  egress_rules = [
    {
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      description     = ""
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    }
  ]
}

module "redis-sg" {
  source      = "../../../../modules/aws/security_groups"
  name        = "redis"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      description = "Allow traffic from Application"
      cidr_blocks = []
      security_groups = [
        module.app_sg.security_group_id
      ]
    }
  ]

  egress_rules = [
    {
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      description     = ""
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    }
  ]
}

module "db-sg" {
  source      = "../../../../modules/aws/security_groups"
  name        = "aurora"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "Allow traffic from Application"
      cidr_blocks = []
      security_groups = [
        module.app_sg.security_group_id
      ]
    },
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "Allow traffic from Bastion"
      cidr_blocks = []
      security_groups = [
        module.bastion_sg.security_group_id
      ]
    }
  ]

  egress_rules = [
    {
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      description     = ""
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    }
  ]
}

module "bastion_sg" {
  source      = "../../../../modules/aws/security_groups"
  name        = "bastion"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Allow SSH traffic"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allow all outbound"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
//-----------------------------------

// SQS Queues
module "sqs_dlq" {
  source      = "../../../../modules/aws/sqs"
  name        = "app-dlq"
  environment = var.environment
  project     = var.project
}

module "sqs" {
  source      = "../../../../modules/aws/sqs"
  name        = "app-queue"
  environment = var.environment
  project     = var.project
  dlq_arn     = module.sqs_dlq.queue_arn
}

module "sqs_delay" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "app-delay-queue"
  environment                = var.environment
  project                    = var.project
  delay_seconds              = 10
  visibility_timeout_seconds = 30
  dlq_arn                    = module.sqs_delay_dlq.queue_arn
}

module "sqs_delay_dlq" {
  source      = "../../../../modules/aws/sqs"
  name        = "app-delay-dlq"
  environment = var.environment
  project     = var.project
}

module "sqs_render_dlq" {
  source      = "../../../../modules/aws/sqs"
  name        = "app-render-dlq"
  environment = var.environment
  project     = var.project
}

module "sqs_render" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "app-render-queue"
  environment                = var.environment
  project                    = var.project
  visibility_timeout_seconds = 90
  max_receive_count          = 3
  dlq_arn                    = module.sqs_render_dlq.queue_arn
}

module "sqs_scan_dlq" {
  source      = "../../../../modules/aws/sqs"
  name        = "app-scan-dlq"
  environment = var.environment
  project     = var.project
}

module "sqs_scan" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "app-scan-queue"
  environment                = var.environment
  project                    = var.project
  visibility_timeout_seconds = 90
  max_receive_count          = 3
  dlq_arn                    = module.sqs_scan_dlq.queue_arn
}
//--------------------------------------


// Aurora Serverless v2
module "aurora" {
  source             = "../../../../modules/aws/aurora"
  cluster_identifier = "aurora-db"

  instance_class = "db.serverless"
  num_instances  = 1

  engine          = "aurora-postgresql"
  engine_version  = "15.15"
  database_name   = "stg_app_db"
  master_username = var.master_db_user_name
  master_password = var.master_db_user_pass

  subnet_ids = [
    module.subnets.private_subnet_ids["db-1"],
    module.subnets.private_subnet_ids["db-2"]
  ]

  security_group_ids = [
    module.db-sg.security_group_id
  ]

  environment = var.environment
  project     = var.project
}
//----------------------------------

// Redis
module "redis" {
  source             = "../../../../modules/aws/elasticache"
  name               = "cache"
  engine             = "redis"
  node_type          = "cache.t3.micro"
  num_cache_clusters = 1
  transit_encryption = false
  at_rest_encryption = false

  subnet_ids = [
    module.subnets.private_subnet_ids["db-1"],
    module.subnets.private_subnet_ids["db-2"]
  ]

  security_group_ids = [
    module.redis-sg.security_group_id
  ]

  environment = var.environment
  project     = var.project
}
//----------------------------

// Load Balancing Tier

# 1. Default target group (webhook / fallback)
module "target_group" {
  source            = "../../../../modules/aws/target_group"
  name              = "app-tg-8080"
  port              = 8080
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = var.health_check_path
  environment       = var.environment
  project           = var.project
}

# 2. WebAPI target group (routes /v1/* on port 443)
module "target_group_webapi" {
  source            = "../../../../modules/aws/target_group"
  name_override     = "stg-sammmm-tg-webapi-8080"
  name              = "tg-webapi-8080"
  port              = 8080
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = var.health_check_path
  environment       = var.environment
  project           = var.project
}

# 3. WebChat target group (routes /v1/ws/* on port 443)
module "target_group_webchat" {
  source            = "../../../../modules/aws/target_group"
  name_override     = "stg-sammmm-tg-webchat-8080"
  name              = "tg-webchat-8080"
  port              = 8080
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = var.health_check_path
  environment       = var.environment
  project           = var.project
}

# 4. Dashboard target group (port 8443 listener → port 8091 on container)
module "target_group_dashboard" {
  source            = "../../../../modules/aws/target_group"
  name_override     = "staging-SAMMMM-app-tg-dash-8091"
  name              = "app-tg-dash-8091"
  port              = 8091
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = var.health_check_path
  environment       = var.environment
  project           = var.project
}

# 4.5. Frontend target group (routes /* on port 443)
module "target_group_frontend" {
  source            = "../../../../modules/aws/target_group"
  name_override     = "stg-sammmm-tg-frontend-3000"
  name              = "tg-frontend-3000"
  port              = 3000
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = "/"
  environment       = var.environment
  project           = var.project
}

# 5. Application Load Balancer (port 443 HTTPS, default → webhook/fallback TG)
module "alb" {
  source   = "../../../../modules/aws/alb"
  name     = "app-alb"
  internal = false
  security_group_ids = [
    module.alb_sg.security_group_id
  ]

  subnet_ids = [
    module.subnets.public_subnet_ids["public-1"],
    module.subnets.public_subnet_ids["public-2"]
  ]

  http_port            = 443
  http_protocol        = "HTTPS"
  http_certificate_arn = "arn:aws:acm:ap-south-1:515966492403:certificate/390cbef8-cfb1-4a5a-81aa-f2a463724290"
  ssl_policy           = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"

  http_default_action   = "forward"
  http_target_group_arn = module.target_group.target_group_arn
  environment           = var.environment
  project               = var.project
}

# 6. ALB Listener Rules (path-based routing on port 443)
# Priority 5 must come before 10 so /v1/ws/* is matched before /v1/*
resource "aws_lb_listener_rule" "webchat" {
  listener_arn = module.alb.http_listener_arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = module.target_group_webchat.target_group_arn
  }

  condition {
    path_pattern {
      values = ["/v1/ws/*"]
    }
  }
}

resource "aws_lb_listener_rule" "webapi" {
  listener_arn = module.alb.http_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = module.target_group_webapi.target_group_arn
  }

  condition {
    path_pattern {
      values = ["/v1/*"]
    }
  }
}

resource "aws_lb_listener_rule" "frontend" {
  listener_arn = module.alb.http_listener_arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = module.target_group_frontend.target_group_arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

# 7. Dashboard listener (port 8443 → dashboard TG on port 8091)
resource "aws_lb_listener" "dashboard" {
  load_balancer_arn = module.alb.alb_arn
  port              = 8443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  certificate_arn   = "arn:aws:acm:ap-south-1:515966492403:certificate/390cbef8-cfb1-4a5a-81aa-f2a463724290"

  default_action {
    type             = "forward"
    target_group_arn = module.target_group_dashboard.target_group_arn
  }

  tags = {
    Name        = "${var.environment}-${var.project}-dashboard-listener"
    Environment = var.environment
    Project     = var.project
  }
}
//--------------------------

// ECS Cluster
# Extracted from the former ecs_fargate module so the cluster can be shared
# across all services without being tied to a single service definition.
module "ecs_cluster" {
  source       = "../../../../modules/aws/ecs_cluster"
  cluster_name = "${var.environment}-${var.project}-app-sammmm"
  environment  = var.environment
  project      = var.project
}

// ECR
module "ecr" {
  source               = "../../../../modules/aws/ecr"
  name                 = "sammmm-backend"
  environment          = var.environment
  project              = var.project
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = false
}

module "ecr_frontend" {
  source               = "../../../../modules/aws/ecr"
  name                 = "sam-frontend"
  environment          = var.environment
  project              = var.project
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = false
}

// =============================================================
// Secrets Manager
// =============================================================

module "secret_database_url" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/DATABASE_URL"
  secret_string = "postgresql://${var.master_db_user_name}:${var.master_db_user_pass}@${module.aurora.cluster_endpoint}:5432/stg_app_db"
  environment   = var.environment
  project       = var.project
}

module "secret_gupshup_hmac_secret" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/GUPSHUP_HMAC_SECRET"
  secret_string = var.secret_gupshup_hmac_secret
  environment   = var.environment
  project       = var.project
}

module "secret_gupshup_token" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/GUPSHUP_TOKEN"
  secret_string = var.secret_gupshup_token
  environment   = var.environment
  project       = var.project
}

module "secret_clevertap_passcode" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/CLEVERTAP_PASSCODE"
  secret_string = var.secret_clevertap_passcode
  environment   = var.environment
  project       = var.project
}

module "secret_google_api_key" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/GOOGLE_API_KEY"
  secret_string = var.secret_google_api_key
  environment   = var.environment
  project       = var.project
}

module "secret_openai_api_key" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/OPENAI_API_KEY"
  secret_string = var.secret_openai_api_key
  environment   = var.environment
  project       = var.project
}

module "secret_deeptag_api_key" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/DEEPTAG_API_KEY"
  secret_string = var.secret_deeptag_api_key
  environment   = var.environment
  project       = var.project
}

module "secret_email_smtp_password" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/EMAIL_SMTP_PASSWORD"
  secret_string = var.secret_email_smtp_password
  environment   = var.environment
  project       = var.project
}

module "secret_gupshup_numbers" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/GUPSHUP_NUMBERS"
  secret_string = var.secret_gupshup_numbers
  environment   = var.environment
  project       = var.project
}

// =============================================================
// IAM — Shared assume-role policy + per-service roles & policies
// =============================================================

locals {
  ecs_task_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  // Used by ingest and flush workers
  sam_env_vars = [
    { name = "APP_NAME", value = "sammmm" },
    { name = "APP_ENV", value = var.environment },
    { name = "LOG_LEVEL", value = "info" },
    { name = "LOG_PRETTY", value = "false" },
    { name = "SERVER_HOST", value = "0.0.0.0" },
    { name = "SERVER_PORT", value = "8080" },
    { name = "DB_MAX_CONNS", value = "10" },
    { name = "DB_MAX_CONN_LIFETIME", value = "1h" },
    { name = "REDIS_ADDRS", value = "${module.redis.redis_primary_endpoint}:6379" },
    { name = "REDIS_PASSWORD", value = "" },
    { name = "AWS_REGION", value = var.aws_region },
    { name = "AWS_ENDPOINT_URL", value = "" },
    { name = "SQS_INBOUND_URL", value = module.sqs.queue_url },
    { name = "SQS_FLUSH_URL", value = module.sqs_delay.queue_url },
    { name = "INGEST_SEEN_TTL", value = "24h" },
    { name = "INGEST_SCHEDULE_TTL", value = "30s" },
    { name = "BATCH_WINDOW", value = "3s" },
    { name = "INGEST_MAX_MESSAGES", value = "10" },
    { name = "INGEST_WAIT_SECONDS", value = "5" },
    { name = "INGEST_PENDING_CAP", value = "100" },
    { name = "FLUSH_LOCK_TTL", value = "30s" },
    { name = "FLUSH_CEILING", value = "180s" },
    { name = "FLUSH_HEARTBEAT_INTERVAL", value = "10s" },
    { name = "FLUSH_MAX_MESSAGES", value = "10" },
    { name = "FLUSH_WAIT_SECONDS", value = "5" },
    { name = "FLUSH_COMPLETED_TTL", value = "1h" },
    { name = "GUPSHUP_DISABLED", value = "true" },
    { name = "GUPSHUP_ENDPOINT", value = "" },
    { name = "GUPSHUP_TEMPLATE_ENDPOINT", value = "" },
    { name = "GUPSHUP_SOURCE", value = "" },
    { name = "GUPSHUP_IDEMPOTENCY_FIELD", value = "messageId" },
    { name = "DISPATCH_WINDOW", value = "24h" },
    { name = "DISPATCH_TEMPLATE_NAME", value = "sammmm_session_reactivation" },
    { name = "CLEVERTAP_DISABLED", value = "true" },
    { name = "CLEVERTAP_ENDPOINT", value = "https://api.clevertap.com/1/upload.json" },
    { name = "CLEVERTAP_ACCOUNT_ID", value = "" },
    { name = "CLEVERTAP_EVENT_NAME", value = "co_creation_completed" },
    { name = "COST_DAILY_LIMIT", value = "25000" },
    { name = "COST_TICK_INTERVAL", value = "60s" },
    { name = "HEALTH_PORT", value = "9091" },
    { name = "HEALTH_SHUTDOWN_TIMEOUT", value = "5s" },
    { name = "HEALTH_PROBE_TIMEOUT", value = "2s" },
    { name = "GEMINI_MODEL", value = "gemini-2.5-flash" },
    { name = "LLM_FALLBACK_MODEL", value = "gpt-5-nano" },
    { name = "LLM_DEFAULT_CREATOR", value = "heli" },
    { name = "LLM_DEFAULT_PRODUCT", value = "cheek_tint_ph" },
    { name = "LLM_TIMEOUT_SECONDS", value = "50" },
    { name = "SELECTIVE_REASK_ENABLED", value = "false" }
  ]

  // webapi / webchat / dashboard add these on top of sam_env_vars
  sam_webapi_env_vars = concat(local.sam_env_vars, [
    { name = "DEEPTAG_TIMEOUT", value = "90s" },
    { name = "DEEPTAG_DISABLED", value = "false" },
    { name = "DEEPTAG_BASE_URL", value = "https://gserver1.btbp.org/deeptag/AppService.svc" },
    { name = "WEBHOOK_SECRET", value = var.webhook_secret },
    { name = "MESSAGES_REFRESH_TTL", value = "5m" },
    { name = "WEBAPI_ALLOWED_ORIGINS", value = "*" },
    { name = "WEBAPI_COOKIE_SAME_SITE", value = "none" },
    { name = "COMPLETION_SUMMARY_ENABLED", value = "true" },
    { name = "MIDLINER_THRESHOLDS", value = "12,18,20" },
    { name = "BIOMETRIC_CONSENT_VERSION", value = "v1.0" },
  ])

  // Secrets for ingest / flush workers
  sam_secrets = [
    { name = "DATABASE_URL", valueFrom = module.secret_database_url.secret_arn },
    { name = "GUPSHUP_HMAC_SECRET", valueFrom = module.secret_gupshup_hmac_secret.secret_arn },
    { name = "GUPSHUP_TOKEN", valueFrom = module.secret_gupshup_token.secret_arn },
    { name = "CLEVERTAP_PASSCODE", valueFrom = module.secret_clevertap_passcode.secret_arn }
  ]

  // Secrets for webapi / webchat / dashboard
  sam_api_secrets = [
    { name = "DATABASE_URL", valueFrom = module.secret_database_url.secret_arn },
    { name = "GUPSHUP_HMAC_SECRET", valueFrom = module.secret_gupshup_hmac_secret.secret_arn },
    { name = "GUPSHUP_TOKEN", valueFrom = module.secret_gupshup_token.secret_arn },
    { name = "CLEVERTAP_PASSCODE", valueFrom = module.secret_clevertap_passcode.secret_arn },
    { name = "GOOGLE_API_KEY", valueFrom = module.secret_google_api_key.secret_arn },
    { name = "DEEPTAG_API_KEY", valueFrom = module.secret_deeptag_api_key.secret_arn },
  ]

  // Secrets for pdf / scan workers
  sam_worker_v2_secrets = [
    { name = "DATABASE_URL", valueFrom = module.secret_database_url.secret_arn },
    { name = "CLEVERTAP_PASSCODE", valueFrom = module.secret_clevertap_passcode.secret_arn },
    { name = "GUPSHUP_TOKEN", valueFrom = module.secret_gupshup_token.secret_arn },
    { name = "GOOGLE_API_KEY", valueFrom = module.secret_google_api_key.secret_arn },
    { name = "DEEPTAG_API_KEY", valueFrom = module.secret_deeptag_api_key.secret_arn },
    { name = "EMAIL_SMTP_PASSWORD", valueFrom = module.secret_email_smtp_password.secret_arn },
    { name = "OPENAI_API_KEY", valueFrom = module.secret_openai_api_key.secret_arn },
  ]
}

// =============================================================
// IAM Roles — per service
// =============================================================

# Roles previously created internally by module "ecs_fargate".
# webapi, webchat and dashboard all use these two roles.
module "webhook_task_exec_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-sammmm-webhook-task-exec-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  environment = var.environment
  project     = var.project
}

module "webhook_task_task_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-sammmm-webhook-task-task-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = []
  environment        = var.environment
  project            = var.project
}

# 1. Webhook / WebAPI policy (SQS send + Secrets)
resource "aws_iam_policy" "webhook_policy" {
  name        = "${var.environment}-${var.project}-webhook-policy"
  description = "Permissions for Sammmm webhook service to access SQS and Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
        Resource = [module.sqs.queue_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = ["*"]
      }
    ]
  })
}

module "webhook_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-webhook-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = []
  environment        = var.environment
  project            = var.project
}

resource "aws_iam_role_policy_attachment" "webhook_attachment" {
  role       = module.webhook_role.role_name
  policy_arn = aws_iam_policy.webhook_policy.arn
}

# 2. Ingest policy
resource "aws_iam_policy" "ingest_policy" {
  name        = "${var.environment}-${var.project}-ingest-policy"
  description = "Permissions for Sammmm ingest service to process inbound and queue to flush SQS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [module.sqs.queue_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [module.sqs_delay.queue_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = ["*"]
      }
    ]
  })
}

module "ingest_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-ingest-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = []
  environment        = var.environment
  project            = var.project
}

resource "aws_iam_role_policy_attachment" "ingest_attachment" {
  role       = module.ingest_role.role_name
  policy_arn = aws_iam_policy.ingest_policy.arn
}

# 3. Flush policy
resource "aws_iam_policy" "flush_policy" {
  name        = "${var.environment}-${var.project}-flush-policy"
  description = "Permissions for Sammmm flush and migrate service to read flush SQS and Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [module.sqs_delay.queue_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = ["*"]
      }
    ]
  })
}

module "flush_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-flush-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = []
  environment        = var.environment
  project            = var.project
}

resource "aws_iam_role_policy_attachment" "flush_attachment" {
  role       = module.flush_role.role_name
  policy_arn = aws_iam_policy.flush_policy.arn
}

# 4. Shared ECS task execution role (used by ingest, flush, pdf, scan)
module "ecs_execution_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-ecs-execution-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  environment = var.environment
  project     = var.project
}

resource "aws_iam_policy" "ecs_execution_secrets_policy" {
  name        = "${var.environment}-${var.project}-ecs-execution-secrets"
  description = "Allows ECS Execution Role to fetch application secrets from Secrets Manager at startup and manage log groups"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:515966492403:log-group:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_secrets_attachment" {
  role       = module.ecs_execution_role.role_name
  policy_arn = aws_iam_policy.ecs_execution_secrets_policy.arn
}

# Attach secrets policy to the webhook-task exec role (used by webapi/webchat/dashboard)
resource "aws_iam_role_policy_attachment" "fargate_execution_secrets" {
  role       = module.webhook_task_exec_role.role_name
  policy_arn = aws_iam_policy.ecs_execution_secrets_policy.arn
}

# Attach webhook SQS + secret permissions to the webhook-task task role
resource "aws_iam_role_policy_attachment" "fargate_task_webhook" {
  role       = module.webhook_task_task_role.role_name
  policy_arn = aws_iam_policy.webhook_policy.arn
}

// =============================================================
// ECS Services
// =============================================================

# Ingest — reads from app-queue, writes to app-delay-queue
module "ecs_ingest" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-ingest"
  family             = "${var.environment}-${var.project}-sammmm-ingest-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.ingest_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"

  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [
    module.app_sg.security_group_id
  ]
  assign_public_ip = false

  container_definitions = jsonencode([
    {
      name         = "ingest"
      image        = "${module.ecr.repository_url}:latest"
      essential    = true
      command      = ["ingest"]
      portMappings = []
      environment  = local.sam_env_vars
      secrets      = local.sam_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/staging-SAMMMM-sammmm-ingest"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  environment = var.environment
  project     = var.project
}

# Flush — reads from app-delay-queue
module "ecs_flush" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-flush"
  family             = "${var.environment}-${var.project}-sammmm-flush-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.flush_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"

  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [
    module.app_sg.security_group_id
  ]
  assign_public_ip = false

  container_definitions = jsonencode([
    {
      name         = "flush"
      image        = "${module.ecr.repository_url}:latest"
      essential    = true
      command      = ["flush"]
      portMappings = []
      environment  = local.sam_env_vars
      secrets      = local.sam_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/staging-SAMMMM-sammmm-flush"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  environment = var.environment
  project     = var.project
}

# WebAPI — HTTP API server on port 8080, ALB routes /v1/*
module "ecs_webapi" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-webapi"
  family             = "${var.environment}-${var.project}-sammmm-webapi-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.webhook_task_exec_role.role_arn
  task_role_arn      = module.webhook_task_task_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"

  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [
    module.app_sg.security_group_id
  ]
  assign_public_ip = false

  target_group_arn = module.target_group_webapi.target_group_arn
  container_name   = "webapi"
  container_port   = 8080

  container_definitions = jsonencode([
    {
      name      = "webapi"
      image     = "${module.ecr.repository_url}:latest"
      essential = true
      command   = ["webapi"]
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = local.sam_webapi_env_vars
      secrets     = local.sam_api_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/staging-sammmm-webapi"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  environment = var.environment
  project     = var.project
}

# WebChat — WebSocket server on port 8080, ALB routes /v1/ws/*
module "ecs_webchat" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-webchat"
  family             = "${var.environment}-${var.project}-sammmm-webchat-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "1024"
  memory             = "2048"
  execution_role_arn = module.webhook_task_exec_role.role_arn
  task_role_arn      = module.webhook_task_task_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"

  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [
    module.app_sg.security_group_id
  ]
  assign_public_ip = false

  target_group_arn = module.target_group_webchat.target_group_arn
  container_name   = "webchat"
  container_port   = 8080

  container_definitions = jsonencode([
    {
      name      = "webchat"
      image     = "${module.ecr.repository_url}:latest"
      essential = true
      command   = ["webchat"]
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = local.sam_webapi_env_vars
      secrets     = local.sam_api_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/staging-sammmm-webchat"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "webchat"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  environment = var.environment
  project     = var.project
}

# Dashboard — internal UI server on port 8091, accessed via ALB port 8443
module "ecs_dashboard" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-dashboard"
  family             = "${var.environment}-${var.project}-sammmm-dashboard-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.webhook_task_exec_role.role_arn
  task_role_arn      = module.webhook_task_task_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"

  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [
    module.app_sg.security_group_id
  ]
  assign_public_ip = false

  target_group_arn = module.target_group_dashboard.target_group_arn
  container_name   = "dashboard"
  container_port   = 8091

  container_definitions = jsonencode([
    {
      name      = "dashboard"
      image     = "${module.ecr.repository_url}:latest"
      essential = true
      command   = ["dashboard"]
      portMappings = [
        {
          containerPort = 8091
          hostPort      = 8091
          protocol      = "tcp"
        }
      ]
      environment = local.sam_webapi_env_vars
      secrets     = local.sam_api_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/staging-sammmm-dashboard"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  environment = var.environment
  project     = var.project
}

# PDF — background worker, generates PDF reports, no ALB
module "ecs_pdf" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-pdf"
  family             = "${var.environment}-${var.project}-sammmm-pdf-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "1024"
  memory             = "2048"
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.flush_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"

  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [
    module.app_sg.security_group_id
  ]
  assign_public_ip = false

  container_definitions = jsonencode([
    {
      name         = "pdf"
      image        = "${module.ecr.repository_url}:latest"
      essential    = true
      command      = ["pdf"]
      portMappings = []
      environment  = local.sam_env_vars
      secrets      = local.sam_worker_v2_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/staging-SAMMMM-sammmm-pdf"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  environment = var.environment
  project     = var.project
}

# Scan — background worker, image scanning, no ALB
module "ecs_scan" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-scan"
  family             = "${var.environment}-${var.project}-sammmm-scan-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "512"
  memory             = "1024"
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.flush_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"

  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [
    module.app_sg.security_group_id
  ]
  assign_public_ip = false

  container_definitions = jsonencode([
    {
      name         = "scan"
      image        = "${module.ecr.repository_url}:latest"
      essential    = true
      command      = ["scan"]
      portMappings = []
      environment  = local.sam_env_vars
      secrets      = local.sam_worker_v2_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/staging-SAMMMM-sammmm-scan"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  environment = var.environment
  project     = var.project
}

// =============================================================
// Bastion Host (EC2 + SSM + DB Access)
// =============================================================

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

module "bastion_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  environment = var.environment
  project     = var.project
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.environment}-${var.project}-bastion-profile"
  role = module.bastion_role.role_name
}

module "bastion_host" {
  source               = "../../../../modules/aws/ec2"
  name                 = "bastion"
  ami_id               = data.aws_ssm_parameter.al2023_ami.value
  instance_type        = "t3.micro"
  subnet_id            = module.subnets.public_subnet_ids["public-1"]
  security_group_ids   = [module.bastion_sg.security_group_id]
  associate_public_ip  = true
  iam_instance_profile = aws_iam_instance_profile.bastion_profile.name
  key_name             = var.bastion_key_name
  environment          = var.environment
  project              = var.project
}

# Frontend — accessed via ALB root path /*
module "ecs_frontend" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-sam-frontend"
  family             = "${var.environment}-${var.project}-sam-frontend-task"
  environment        = var.environment
  project            = var.project
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.webhook_task_exec_role.role_arn
  task_role_arn      = module.webhook_task_task_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [
    module.app_sg.security_group_id
  ]
  assign_public_ip = false

  target_group_arn = module.target_group_frontend.target_group_arn
  container_name   = "frontend"
  container_port   = 3000

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${module.ecr_frontend.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/staging-sammmm-frontend"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}
