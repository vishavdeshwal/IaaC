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
        key          = "sam/prod/terraform.tfstate" # Isolated state for production!
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
    source = "../../../../modules/vpc"
    vpc_cidr = var.vpc_cidr
    instance_tenancy = var.instance_tenancy
    enable_dns_hostnames = var.enable_dns_hostnames
    enable_dns_support = var.enable_dns_support
    environment = var.environment
    project = var.project
}

module "subnets" {
    source = "../../../../modules/subnets"
    vpc_id = module.vpc.vpc_id
    public_subnets = var.public_subnets
    private_subnets = var.private_subnets
    environment = var.environment
    project = var.project
}

module "igw" {
    source = "../../../../modules/igw"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project
}

module "eip" {
    source = "../../../../modules/eip"
    environment = var.environment
    project = var.project
}

module "nat_gateway" {
    source = "../../../../modules/nat_gateway"
    eip_allocation_id = module.eip.eip_allocation_id
    public_subnet_id = module.subnets.public_subnet_ids["public-1"]
    igw_dependency = module.igw.igw_id
    environment = var.environment
    project = var.project
}

module "route_tables" {
    source = "../../../../modules/route_tables"
    vpc_id = module.vpc.vpc_id
    igw_id = module.igw.igw_id
    nat_gateway_id = module.nat_gateway.nat_gateway_id
    environment = var.environment
    project = var.project
}

module "route_table_association" {
    source = "../../../../modules/route_table_association"
    public_subnet_ids = module.subnets.public_subnet_ids
    private_subnet_ids = module.subnets.private_subnet_ids
    public_route_table_id = module.route_tables.public_route_table_id
    private_route_table_id = module.route_tables.private_route_table_id
}



// --------- Security Groups ------------------
module "alb_sg" {
    source = "../../../../modules/security_groups"
    name = "abl"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project

    ingress_rules = [
        {
            from_port = 80
            to_port = 80
            protocol = "tcp"
            description = "Allow HTTP traffic"

            cidr_blocks = ["0.0.0.0/0"]
        },
        {
            from_port = 443
            to_port = 443
            protocol = "tcp"
            description = "Allow HTTPS traffic"
            cidr_blocks = ["0.0.0.0/0"]
        }
    ]

    egress_rules = [
        {
            from_port = 0
            to_port = 0
            protocol = "-1"
            description = ""
            cidr_blocks = ["0.0.0.0/0"]
        }
    ]
}

module "app_sg" {
    source = "../../../../modules/security_groups"

    name = "app"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project

    ingress_rules = [
        {
            from_port = 8080
            to_port = 8080
            protocol = "tcp"
            description = "Allow traffic from ALB"

            cidr_blocks = []
            security_groups = [
                module.alb_sg.security_group_id
            ]
        }
    ]



    egress_rules = [
        {
            from_port = 0
            to_port = 0
            protocol = "-1"
            description = ""
            cidr_blocks = ["0.0.0.0/0"]
            security_groups = []
        }
    ]
}

module "redis-sg" {
    source = "../../../../modules/security_groups"
    name = "redis"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project

    ingress_rules = [
        {
            from_port = 6379
            to_port = 6379
            protocol = "tcp"
            description = "Allow traffic from Application"

            cidr_blocks = []
            security_groups = [
                module.app_sg.security_group_id
            ]
        }
    ]

    egress_rules = [
        {
            from_port = 0
            to_port = 0
            protocol = "-1"
            description = ""
            cidr_blocks = ["0.0.0.0/0"]
            security_groups = []
        }
    ]
}

module "db-sg" {
    source = "../../../../modules/security_groups"

    name = "aurora"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project

    ingress_rules = [
        {
            from_port = 5432
            to_port = 5432
            protocol = "tcp"
            description = "Allow traffic from Application"

            cidr_blocks = []
            security_groups = [
                module.app_sg.security_group_id
            ]
        },
        {
            from_port = 5432
            to_port = 5432
            protocol = "tcp"
            description = "Allow traffic from Bastion"

            cidr_blocks = []
            security_groups = [
                module.bastion_sg.security_group_id
            ]
        }
    ]

    egress_rules = [
        {
            from_port = 0
            to_port = 0
            protocol = "-1"
            description = ""
            cidr_blocks = ["0.0.0.0/0"]
            security_groups = []
        }
    ]
}

module "bastion_sg" {
    source = "../../../../modules/security_groups"
    name = "bastion"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project

    ingress_rules = [
        {
            from_port = 22
            to_port = 22
            protocol = "tcp"
            description = "Allow SSH traffic"
            cidr_blocks = ["0.0.0.0/0"]
        }
    ]

    egress_rules = [
        {
            from_port = 0
            to_port = 0
            protocol = "-1"
            description = "Allow all outbound"
            cidr_blocks = ["0.0.0.0/0"]
        }
    ]
}
//-----------------------------------

// SQS_DQL and SQS Queue

module "sqs_dlq" {
    source = "../../../../modules/sqs"
    name = "app-dlq"
    environment = var.environment
    project = var.project
}


module "sqs" {
    source = "../../../../modules/sqs"
    name = "app-queue"
    environment = var.environment
    project = var.project

    dlq_arn = module.sqs_dlq.queue_arn
}

module "sqs_delay" {
    source = "../../../../modules/sqs"
    name = "app-delay-queue"
    environment = var.environment
    project = var.project
    delay_seconds = 10
    visibility_timeout_seconds = 30
    dlq_arn = module.sqs_delay_dlq.queue_arn
}

module "sqs_delay_dlq" {
    source = "../../../../modules/sqs"
    name = "app-delay-dlq"
    environment = var.environment
    project = var.project
}


//--------------------------------------


// Aurora Serverless v2 ----------

module "aurora" {
    source = "../../../../modules/aurora"
    cluster_identifier = "aurora-db"
    
    # Enable Serverless v2
    instance_class = "db.serverless"
    num_instances = 1
    serverlessv2_min_capacity = 3
    serverlessv2_max_capacity = 16

    engine = "aurora-postgresql"
    engine_version = "15.14"
    database_name = "prod_app_db"
    master_username = var.master_db_user_name
    master_password = var.master_db_user_pass

    subnet_ids = [
        module.subnets.private_subnet_ids["db-1"],
        module.subnets.private_subnet_ids["db-2"]
    ]
    
    security_group_ids = [
        module.db-sg.security_group_id
    ]

    performance_insights_enabled          = true
    performance_insights_retention_period = 7
    apply_immediately                     = true

    environment = var.environment
    project = var.project
}
//----------------------------------

// --------- Redis ----------
module "redis" {
    source = "../../../../modules/elasticache"
    name = "cache"
    engine = "redis"
    node_type = "cache.t3.micro"
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
    project = var.project
}



//----------------------------
// Load Balancing Tier
# 1. Target Group (Routing destination for Fargate containers)

module "target_group" {
    source = "../../../../modules/target_group"
    name = "app-tg-8080"
    port = 8080
    protocol = "HTTP"
    target_type = "ip"
    vpc_id = module.vpc.vpc_id
    health_check_path = var.health_check_path
    environment = var.environment
    project = var.project
}

# 2 Application Load Balancer (Receives web traffic)

module "alb" {
    source = "../../../../modules/alb"
    name = "app-alb"
    internal = false
    security_group_ids = [
        module.alb_sg.security_group_id
    ]

    subnet_ids = [
        module.subnets.public_subnet_ids["public-1"],
        module.subnets.public_subnet_ids["public-2"]
    ]

    http_default_action = "forward"
    http_target_group_arn = module.target_group.target_group_arn
    environment = var.environment
    project = var.project
}
//--------------------------

// Container Runtime Tier
# ECS Fargate Cluster & Service

module "ecs_fargate" {
    source = "../../../../modules/ecs_fargate"
    cluster_name = "app-sammmm"
    service_name = "sammmm-webhook"
    task_family = "sammmm-webhook-task"

    cpu = 256
    memory = 512
    desired_count = 1

    subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
   ]

   security_group_ids = [
    module.app_sg.security_group_id
   ]

    # Bind to to ALB
    target_group_arn = module.target_group.target_group_arn
    container_name = "webhook"
    container_port = 8080

    # Container Specifications
    container_definitions = jsonencode ([
        {
            name = "webhook"
            image = "${module.ecr.repository_url}:latest"
            essential = true
            command = ["webhook"]

            portMappings = [
                {
                    containerPort = 8080
                    hostPort = 8080
                    protocol = "tcp"
                }
            ]

            environment = local.sam_env_vars
            secrets     = local.sam_secrets

            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    "awslogs-group" = "/ecs/${var.environment}-sammmm-webhook"
                    "awslogs-region" = var.aws_region
                    "awslogs-stream-prefix" = "ecs"
                    "awslogs-create-group" = "true"
                }
            }
        }
    ])
    environment = var.environment
    project = var.project
}

module "ecr" {
    source = "../../../../modules/ecr"
    name = "sammmm-backend"
    environment = var.environment
    project = var.project
    image_tag_mutability = "IMMUTABLE"
    scan_on_push = false

}

// =============================================================
// Secrets Manager Integration (Modularized)
// =============================================================

module "secret_database_url" {
  source        = "../../../../modules/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/DATABASE_URL"
  secret_string = "postgresql://${var.master_db_user_name}:${var.master_db_user_pass}@${module.aurora.cluster_endpoint}:5432/prod_app_db"
  environment   = var.environment
  project       = var.project
}


module "secret_gupshup_hmac_secret" {
  source        = "../../../../modules/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/GUPSHUP_HMAC_SECRET"
  secret_string = var.secret_gupshup_hmac_secret
  environment   = var.environment
  project       = var.project
}


module "secret_gupshup_token" {
  source        = "../../../../modules/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/GUPSHUP_TOKEN"
  secret_string = var.secret_gupshup_token
  environment   = var.environment
  project       = var.project
}

module "secret_clevertap_passcode" {
  source        = "../../../../modules/secrets_manager"
  secret_name   = "${var.environment}/${var.project}/CLEVERTAP_PASSCODE"
  secret_string = var.secret_clevertap_passcode
  environment   = var.environment
  project       = var.project
}


// =============================================================
// ECS Task Roles & Policies (Modularized)
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
    { name = "GOOGLE_API_KEY", value = "AIzaSyC4iRJb0-RBcvk3qNusRrvQd5BKXNyXMuE" },
    { name = "GEMINI_MODEL", value = "gemini-2.5-flash" },
    { name = "OPENAI_API_KEY", value = "" },
    { name = "LLM_FALLBACK_MODEL", value = "gpt-5-nano" },
    { name = "LLM_DEFAULT_CREATOR", value = "heli" },
    { name = "LLM_DEFAULT_PRODUCT", value = "cheek_tint_ph" },
    { name = "LLM_TIMEOUT_SECONDS", value = "50" },
    { name = "SELECTIVE_REASK_ENABLED", value = "false" }
  ]

  sam_secrets = [
    { name = "DATABASE_URL", valueFrom = module.secret_database_url.secret_arn },
    { name = "GUPSHUP_HMAC_SECRET", valueFrom = module.secret_gupshup_hmac_secret.secret_arn },
    { name = "GUPSHUP_TOKEN", valueFrom = module.secret_gupshup_token.secret_arn },
    { name = "CLEVERTAP_PASSCODE", valueFrom = module.secret_clevertap_passcode.secret_arn }
  ]
}

# 1. Webhook Service Task Role & Policy
resource "aws_iam_policy" "webhook_policy" {
  name        = "${var.environment}-${var.project}-webhook-policy"
  description = "Permissions for Sammmm webhook service to access SQS and Secrets Manager"
  policy      = jsonencode({
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
  source             = "../../../../modules/iam_role"
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

# 2. Ingest Service Task Role & Policy
resource "aws_iam_policy" "ingest_policy" {
  name        = "${var.environment}-${var.project}-ingest-policy"
  description = "Permissions for Sammmm ingest service to process inbound and queue to flush SQS"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
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
  source             = "../../../../modules/iam_role"
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

# 3. Flush Service Task Role & Policy
resource "aws_iam_policy" "flush_policy" {
  name        = "${var.environment}-${var.project}-flush-policy"
  description = "Permissions for Sammmm flush and migrate service to read flush SQS and Secrets Manager"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
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
  source             = "../../../../modules/iam_role"
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

# 4. ECS Task Execution Role (separate from task role)
module "ecs_execution_role" {
  source             = "../../../../modules/iam_role"
  name               = "${var.environment}-${var.project}-ecs-execution-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  policy_arns        = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  environment        = var.environment
  project            = var.project
}

# Task Execution Role Secrets Policy (Allows ECS to fetch secrets at startup and write/create log groups)
resource "aws_iam_policy" "ecs_execution_secrets_policy" {
  name        = "${var.environment}-${var.project}-ecs-execution-secrets"
  description = "Allows ECS Execution Role to fetch application secrets from Secrets Manager at startup and manage log groups"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = [
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

# 5. Attach Secrets Access to the internally managed Fargate task execution role
resource "aws_iam_role_policy_attachment" "fargate_execution_secrets" {
  role       = "${var.environment}-${var.project}-sammmm-webhook-task-exec-role"
  policy_arn = aws_iam_policy.ecs_execution_secrets_policy.arn
}

# 6. Attach Webhook SQS and Secret permissions to the internally managed Fargate task role
resource "aws_iam_role_policy_attachment" "fargate_task_webhook" {
  role       = "${var.environment}-${var.project}-sammmm-webhook-task-task-role"
  policy_arn = aws_iam_policy.webhook_policy.arn
}


// =============================================================
// Background Worker ECS Services (Ingest & Flush)
// =============================================================

module "ecs_ingest" {
  source             = "../../../../modules/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-ingest"
  family             = "${var.environment}-${var.project}-sammmm-ingest-task"
  cluster_arn        = module.ecs_fargate.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.ingest_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"

  subnet_ids         = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [
    module.app_sg.security_group_id
  ]
  assign_public_ip   = false

  container_definitions = jsonencode([
    {
      name      = "ingest"
      image     = "${module.ecr.repository_url}:latest"
      essential = true
      command   = ["ingest"]
      portMappings = []

      environment = local.sam_env_vars
      secrets     = local.sam_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-SAMMMM-sammmm-ingest"
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


module "ecs_flush" {
  source             = "../../../../modules/ecs_service"
  service_name       = "${var.environment}-${var.project}-sammmm-flush"
  family             = "${var.environment}-${var.project}-sammmm-flush-task"
  cluster_arn        = module.ecs_fargate.cluster_arn
  cpu                = "256"
  memory             = "512"
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.flush_role.role_arn
  desired_count      = 1
  launch_type        = "FARGATE"

  subnet_ids         = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [
    module.app_sg.security_group_id
  ]
  assign_public_ip   = false

  container_definitions = jsonencode([
    {
      name      = "flush"
      image     = "${module.ecr.repository_url}:latest"
      essential = true
      command   = ["flush"]
      portMappings = []

      environment = local.sam_env_vars
      secrets     = local.sam_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-SAMMMM-sammmm-flush"
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
// Bastion Host Integration (EC2 with SSM & DB Access)
// =============================================================

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

module "bastion_role" {
  source             = "../../../../modules/iam_role"
  name               = "${var.environment}-${var.project}-bastion-role"
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
  environment        = var.environment
  project            = var.project
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.environment}-${var.project}-bastion-profile"
  role = module.bastion_role.role_name
}

module "bastion_host" {
  source               = "../../../../modules/ec2"
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
