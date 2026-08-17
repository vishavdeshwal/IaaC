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
    key          = "sam/preprod/terraform.tfstate"
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

module "sqs_flush_dlq" {
  source      = "../../../../modules/aws/sqs"
  name        = "app-flush-dlq"
  environment = var.environment
  project     = var.project
  fifo_queue  = true
}

module "sqs_flush" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "app-flush"
  environment                = var.environment
  project                    = var.project
  fifo_queue                 = true
  high_throughput_fifo       = true
  visibility_timeout_seconds = 180
  dlq_arn                    = module.sqs_flush_dlq.queue_arn
}

module "sqs_email_dlq" {
  source      = "../../../../modules/aws/sqs"
  name        = "app-email-dlq"
  environment = var.environment
  project     = var.project
}

module "sqs_email" {
  source                     = "../../../../modules/aws/sqs"
  name                       = "app-email-queue"
  environment                = var.environment
  project                    = var.project
  visibility_timeout_seconds = 90
  max_receive_count          = 3
  dlq_arn                    = module.sqs_email_dlq.queue_arn
}
//--------------------------------------


// Aurora Serverless v2
module "aurora" {
  source             = "../../../../modules/aws/aurora"
  cluster_identifier = "aurora-db"

  instance_class = "db.serverless"
  num_instances  = 1

  engine                    = "aurora-postgresql"
  engine_version            = "15.14"
  serverlessv2_min_capacity = 3
  serverlessv2_max_capacity = 16
  database_name             = "preprod_app_db"
  master_username           = var.master_db_user_name
  master_password           = var.master_db_user_pass

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
  name_override     = "preprod-sammmm-tg-webapi-8080"
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
  name_override     = "preprod-sammmm-tg-webchat-8080"
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
  name_override     = "preprod-SAMMMM-app-tg-dash-8091"
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
  name_override     = "preprod-sammmm-tg-frontend-3000"
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
  http_certificate_arn = "arn:aws:acm:ap-south-1:515966492403:certificate/21d69985-198b-435c-aa1b-7a47c45d5510"
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

resource "aws_lb_listener_rule" "dashboard" {
  listener_arn = module.alb.http_listener_arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = module.target_group_dashboard.target_group_arn
  }

  condition {
    path_pattern {
      values = ["/dashboard", "/dashboard/*"]
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

//--------------------------

// ECS Cluster
# Extracted from the former ecs_fargate module so the cluster can be shared
# across all services without being tied to a single service definition.
module "ecs_cluster" {
  source       = "../../../../modules/aws/ecs_cluster"
  cluster_name = "${var.environment}-${var.project}-app-sammmm"

  # Matches deployed reality. Cost review proposes dropping preprod to
  # "disabled" (baseline) — change deliberately, not as drift cleanup.
  enable_container_insights = true
  container_insights_value  = "enhanced"

  environment = var.environment
  project     = var.project
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

module "secret_app_secrets" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/APP_SECRETS"
  secret_string = "{}"
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
    { name = "DATABASE_URL", valueFrom = "${module.secret_app_secrets.secret_arn}:DATABASE_URL::" },
    { name = "GUPSHUP_HMAC_SECRET", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_HMAC_SECRET::" },
    { name = "GUPSHUP_TOKEN", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_TOKEN::" },
    { name = "CLEVERTAP_PASSCODE", valueFrom = "${module.secret_app_secrets.secret_arn}:CLEVERTAP_PASSCODE::" },
    { name = "GUPSHUP_SMS_PASSWORD", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_SMS_PASSWORD::" },
    { name = "GUPSHUP_NUMBERS", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_NUMBERS::" },
    { name = "SHOPIFY_TOKEN", valueFrom = "${module.secret_app_secrets.secret_arn}:SHOPIFY_TOKEN::" }
  ]

  // Secrets for webapi / webchat / dashboard
  sam_api_secrets = [
    { name = "DATABASE_URL", valueFrom = "${module.secret_app_secrets.secret_arn}:DATABASE_URL::" },
    { name = "GUPSHUP_HMAC_SECRET", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_HMAC_SECRET::" },
    { name = "GUPSHUP_TOKEN", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_TOKEN::" },
    { name = "CLEVERTAP_PASSCODE", valueFrom = "${module.secret_app_secrets.secret_arn}:CLEVERTAP_PASSCODE::" },
    { name = "GOOGLE_API_KEY", valueFrom = "${module.secret_app_secrets.secret_arn}:GOOGLE_API_KEY::" },
    { name = "DEEPTAG_API_KEY", valueFrom = "${module.secret_app_secrets.secret_arn}:DEEPTAG_API_KEY::" },
    { name = "GUPSHUP_SMS_PASSWORD", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_SMS_PASSWORD::" },
    { name = "GUPSHUP_NUMBERS", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_NUMBERS::" },
    { name = "SHOPIFY_TOKEN", valueFrom = "${module.secret_app_secrets.secret_arn}:SHOPIFY_TOKEN::" }
  ]

  // Secrets for pdf / scan workers
  sam_worker_v2_secrets = [
    { name = "DATABASE_URL", valueFrom = "${module.secret_app_secrets.secret_arn}:DATABASE_URL::" },
    { name = "CLEVERTAP_PASSCODE", valueFrom = "${module.secret_app_secrets.secret_arn}:CLEVERTAP_PASSCODE::" },
    { name = "GUPSHUP_TOKEN", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_TOKEN::" },
    { name = "GOOGLE_API_KEY", valueFrom = "${module.secret_app_secrets.secret_arn}:GOOGLE_API_KEY::" },
    { name = "DEEPTAG_API_KEY", valueFrom = "${module.secret_app_secrets.secret_arn}:DEEPTAG_API_KEY::" },
    { name = "EMAIL_SMTP_PASSWORD", valueFrom = "${module.secret_app_secrets.secret_arn}:EMAIL_SMTP_PASSWORD::" },
    { name = "OPENAI_API_KEY", valueFrom = "${module.secret_app_secrets.secret_arn}:OPENAI_API_KEY::" },
    { name = "GUPSHUP_SMS_PASSWORD", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_SMS_PASSWORD::" },
    { name = "GUPSHUP_NUMBERS", valueFrom = "${module.secret_app_secrets.secret_arn}:GUPSHUP_NUMBERS::" },
    { name = "SHOPIFY_TOKEN", valueFrom = "${module.secret_app_secrets.secret_arn}:SHOPIFY_TOKEN::" }
  ]
}



// =============================================================
// IAM Roles — per service
// =============================================================



# Per-Service Task Roles
module "dashboard_task_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-dashboard-task-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = []
  environment        = var.environment
  project            = var.project
}

module "webapi_task_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-webapi-task-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = []
  environment        = var.environment
  project            = var.project
}

module "webchat_task_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-webchat-task-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = [aws_iam_policy.webchat_task_policy.arn]
  environment        = var.environment
  project            = var.project
}

resource "aws_iam_policy" "webchat_task_policy" {
  name        = "${var.environment}-${var.project}-webchat-task-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EnqueueFlush"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
        Resource = [module.sqs_flush.queue_arn]
      }
    ]
  })
}


resource "aws_iam_policy" "scan_task_policy" {
  name        = "${var.environment}-${var.project}-scan-task-policy"
  description = "Permissions for scan task"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility", "sqs:SendMessage"]
        Resource = [module.sqs_scan.queue_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [module.sqs_flush.queue_arn]
      },
      {
        Sid      = "StageSelfie"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["arn:aws:s3:::sammmm-${var.environment}-scan-images/*"]
      }
    ]
  })
}

module "scan_task_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-scan-task-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = [aws_iam_policy.scan_task_policy.arn]
  environment        = var.environment
  project            = var.project
}

resource "aws_iam_policy" "pdf_task_policy" {
  name        = "${var.environment}-${var.project}-pdf-task-policy"
  description = "Permissions for pdf task"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
        Resource = [module.sqs_render.queue_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [module.sqs_flush.queue_arn]
      },
      {
        Sid      = "WriteReport"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["arn:aws:s3:::sammmm-${var.environment}-bucket/*"]
      },
      {
        Sid      = "ReadSelfieForHydration"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::sammmm-${var.environment}-scan-images/*"]
      }
    ]
  })
}

module "pdf_task_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-pdf-task-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = [aws_iam_policy.pdf_task_policy.arn]
  environment        = var.environment
  project            = var.project
}

resource "aws_iam_policy" "mailer_task_policy" {
  name        = "${var.environment}-${var.project}-mailer-task-policy"
  description = "Permissions for mailer task"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ConsumeEmailQueue"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
        Resource = [module.sqs_email.queue_arn]
      }
    ]
  })
}

module "mailer_task_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-mailer-task-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = [aws_iam_policy.mailer_task_policy.arn]
  environment        = var.environment
  project            = var.project
}

resource "aws_iam_policy" "flush_task_policy" {
  name        = "${var.environment}-${var.project}-flush-task-policy"
  description = "Permissions for flush task"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
        Resource = [module.sqs_flush.queue_arn]
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject"]
        Resource = [
          "arn:aws:s3:::sammmm-${var.environment}-scan-images/*",
          "arn:aws:s3:::sammmm-${var.environment}-bucket/reports/*"
        ]
      },
      {
        Sid      = "EnqueueScanAndRender"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
        Resource = [
          module.sqs_scan.queue_arn,
          module.sqs_render.queue_arn,
          module.sqs_email.queue_arn
        ]
      },
      {
        Sid      = "BedrockInvoke"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = ["*"]
      }
    ]
  })
}

module "flush_task_role" {
  source             = "../../../../modules/aws/iam_role"
  name               = "${var.environment}-${var.project}-flush-task-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = [aws_iam_policy.flush_task_policy.arn]
  environment        = var.environment
  project            = var.project
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
        Resource = ["arn:aws:secretsmanager:${var.aws_region}:515966492403:secret:${var.environment}/${var.project}/*"]
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


// =============================================================
// ECS Services
// =============================================================

# Flush — reads from app-delay-queue
module "ecs_flush" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-flush"
  family             = "${var.environment}-${var.project}-sammmm-flush-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.flush_task_role.role_arn
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
      environment  = concat(local.sam_env_vars, [
        { name = "SQS_EMAIL_URL", value = module.sqs_email.queue_url },
        { name = "THANKYOU_EMAIL_ENABLED", value = "true" }
      ])
      secrets      = local.sam_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-sammmm-flush"
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
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.webapi_task_role.role_arn
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
          protocol      = "tcp"
        }
      ]
      environment = local.sam_webapi_env_vars
      secrets     = local.sam_api_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-webapi"
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
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.webchat_task_role.role_arn
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
          protocol      = "tcp"
        }
      ]
      environment = local.sam_webapi_env_vars
      secrets     = local.sam_api_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-webchat"
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
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.dashboard_task_role.role_arn
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
          protocol      = "tcp"
        }
      ]
      environment = local.sam_webapi_env_vars
      secrets     = local.sam_api_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-dashboard"
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
  task_role_arn      = module.pdf_task_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"
  platform_version   = "1.4.0"

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
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-sammmm-pdf"
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

# Mailer — background worker for sending completion emails
module "ecs_mailer" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-mailer"
  family             = "${var.environment}-${var.project}-sammmm-mailer-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.mailer_task_role.role_arn
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
      name         = "mailer"
      image        = "${module.ecr.repository_url}:latest"
      essential    = true
      command      = ["mailer"]
      portMappings = []
      environment  = concat(local.sam_env_vars, [
        { name = "SQS_EMAIL_URL", value = module.sqs_email.queue_url }
      ])
      secrets      = local.sam_worker_v2_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-sammmm-mailer"
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
  task_role_arn      = module.scan_task_role.role_arn
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
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-sammmm-scan"
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
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = null
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
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-frontend"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

resource "aws_appautoscaling_target" "frontend_target" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${module.ecs_cluster.cluster_name}/${var.environment}-${var.project}-sam-frontend"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "frontend_policy" {
  name               = "${var.environment}-${var.project}-sam-frontend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend_target.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 75.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}


// =============================================================
// Service autoscaling — worker + API services
//
// These were created manually in the console during the launch window and
// were unmanaged until 2026-08-17. Values below mirror deployed reality
// exactly; imported, not recreated. See DRIFT-REPORT-2026-08-11.md §3.1.
//
// Ceilings are deliberately lower than prod (scan/pdf 4 vs 10, flush 6 vs 15).
// =============================================================

locals {
  service_autoscaling = {
    webapi = {
      min_capacity = 2
      max_capacity = 10
      policy_name  = "webapi-cpu60"
      target_value = 60
      queue_name   = null
    }
    webchat = {
      min_capacity = 2
      max_capacity = 8
      policy_name  = "webchat-cpu60"
      target_value = 60
      queue_name   = null
    }
    scan = {
      min_capacity = 1
      max_capacity = 4
      policy_name  = "scan-queue-backlog"
      target_value = 20
      queue_name   = module.sqs_scan.queue_name
    }
    pdf = {
      min_capacity = 1
      max_capacity = 4
      policy_name  = "render-queue-backlog"
      target_value = 20
      queue_name   = module.sqs_render.queue_name
    }
    flush = {
      min_capacity = 2
      max_capacity = 6
      policy_name  = "flush-fifo-backlog"
      target_value = 40
      queue_name   = module.sqs_flush.queue_name
    }
  }
}

resource "aws_appautoscaling_target" "service" {
  for_each = local.service_autoscaling

  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.min_capacity
  resource_id        = "service/${module.ecs_cluster.cluster_name}/${var.environment}-${var.project}-sammmm-${each.key}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "service" {
  for_each = local.service_autoscaling

  name               = each.value.policy_name
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.service[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = each.value.target_value
    scale_out_cooldown = 60
    scale_in_cooldown  = 180

    # CPU-driven services
    dynamic "predefined_metric_specification" {
      for_each = each.value.queue_name == null ? [1] : []
      content {
        predefined_metric_type = "ECSServiceAverageCPUUtilization"
      }
    }

    # Queue-depth-driven workers
    dynamic "customized_metric_specification" {
      for_each = each.value.queue_name != null ? [1] : []
      content {
        metric_name = "ApproximateNumberOfMessagesVisible"
        namespace   = "AWS/SQS"
        statistic   = "Average"

        dimensions {
          name  = "QueueName"
          value = each.value.queue_name
        }
      }
    }
  }
}
