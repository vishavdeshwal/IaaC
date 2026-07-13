terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    # The bucket will be populated from the user's bootstrap output
    bucket  = "alive-wellness-terraform-state-174749"
    key     = "alive-wellness/preprod/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
    profile = "alive-wellness"
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
}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

// =============================================================
// Network
// =============================================================

module "vpc" {
  source               = "../../../../modules/aws/vpc"
  vpc_cidr             = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  instance_tenancy     = var.instance_tenancy
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
  public_subnet_id  = module.subnets.public_subnet_ids["public-1"]
  eip_allocation_id = module.eip.eip_allocation_id
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
  public_route_table_id  = module.route_tables.public_route_table_id
  private_route_table_id = module.route_tables.private_route_table_id
  public_subnet_ids      = module.subnets.public_subnet_ids
  private_subnet_ids     = module.subnets.private_subnet_ids
}

// =============================================================
// Security
// =============================================================

module "app_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "app-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS"
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow Frontend Port"
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow Backend Port"
    },
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [module.bastion_sg.security_group_id]
      description     = "Allow SSH strictly from Bastion Host"
    },
    {
      from_port   = 1337
      to_port     = 1337
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow Strapi Port"
    },
    {
      from_port   = 8000
      to_port     = 8000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow ERP & Saleor Port"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]
}

module "db_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "db-sg"
  environment = var.environment
  project     = var.project
  ingress_rules = [
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.app_sg.security_group_id]
      description     = "Allow DB access from App SG"
    },
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.bastion_sg.security_group_id]
      description     = "Allow DB access from Bastion Host"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]
}

module "redis_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "redis-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [module.app_sg.security_group_id]
      description     = "Allow Redis access from App SG"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]
}

module "bastion_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "bastion-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow SSH from anywhere (restrict in prod)"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]
}

module "ecs_execution_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  environment = var.environment
  project     = var.project
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = module.ecs_execution_role.role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

module "backend_secrets" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}-${var.project}-backend-secrets"
  secret_string = jsonencode(var.backend_secrets)
  environment   = var.environment
  project       = var.project
}

module "ecs_execution_secrets_policy" {
  source      = "../../../../modules/aws/iam_policy"
  name        = "${var.environment}-${var.project}-ecs-secrets-policy"
  description = "Policy to allow ECS execution role to read secrets"
  is_inline   = true
  role_name   = module.ecs_execution_role.role_name
  environment = var.environment
  project     = var.project
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "logs:CreateLogGroup"
        ]
        Resource = [
          module.backend_secrets.secret_arn,
          "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.environment}-${var.project}-*"
        ]
      }
    ]
  })
}

module "ecs_task_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  environment = var.environment
  project     = var.project
}

module "ecs_task_s3_policy" {
  source      = "../../../../modules/aws/iam_policy"
  name        = "${var.environment}-${var.project}-ecs-s3-policy"
  description = "Policy to allow ECS tasks to access the S3 media bucket"
  is_inline   = true
  role_name   = module.ecs_task_role.role_name
  environment = var.environment
  project     = var.project
  policy      = jsonencode({
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
          aws_s3_bucket.media.arn,
          "${aws_s3_bucket.media.arn}/*"
        ]
      }
    ]
  })
}

module "ec2_ssm_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ec2-ssm-role"
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
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  environment = var.environment
  project     = var.project
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.environment}-${var.project}-ssm-profile"
  role = module.ec2_ssm_role.role_name
}

resource "aws_iam_role_policy" "strapi_s3_access" {
  name = "${var.environment}-${var.project}-ec2-s3-access"
  role = module.ec2_ssm_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.media.arn,
          "${aws_s3_bucket.media.arn}/*"
        ]
      }
    ]
  })
}

// =============================================================
// Storage & CDN
// =============================================================

resource "aws_s3_bucket" "media" {
  bucket = "${var.project}-${var.environment}-media-assets"

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket = aws_s3_bucket.media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "cdn" {
  source                         = "../../../../modules/aws/cloudfront"
  s3_bucket_id                   = aws_s3_bucket.media.id
  s3_bucket_regional_domain_name = aws_s3_bucket.media.bucket_regional_domain_name
  environment                    = var.environment
  project                        = var.project
}

resource "aws_s3_bucket_policy" "cdn_access" {
  bucket = aws_s3_bucket.media.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.media.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cdn.cloudfront_distribution_arn
          }
        }
      }
    ]
  })
}

module "ecr_frontend" {
  source       = "../../../../modules/aws/ecr"
  name         = "alive-wellness-frontend"
  environment  = var.environment
  project      = var.project
  scan_on_push = false
}

module "ecr_backend" {
  source       = "../../../../modules/aws/ecr"
  name         = "alive-wellness-backend"
  environment  = var.environment
  project      = var.project
  scan_on_push = false
}

module "ecr_saleor" {
  source       = "../../../../modules/aws/ecr"
  name         = "alive-wellness-saleor"
  environment  = var.environment
  project      = var.project
  scan_on_push = false
}

// =============================================================
// Database & Cache
// =============================================================

# Standard RDS PostgreSQL for Backend and Saleor
module "rds_postgres" {
  source            = "../../../../modules/aws/rds"
  identifier        = "postgres"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.medium"
  allocated_storage = 200
  username          = var.master_db_user_name
  password          = var.master_db_user_pass
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [module.db_sg.security_group_id]
  environment        = var.environment
  project            = var.project
}

# Redis Cluster
module "redis" {
  source             = "../../../../modules/aws/elasticache"
  name               = "redis"
  engine             = "redis"
  node_type          = "cache.t3.micro"
  num_cache_clusters = 1
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  security_group_ids = [module.redis_sg.security_group_id]
  environment        = var.environment
  project            = var.project
}

// =============================================================
// Queues
// =============================================================

module "sqs" {
  source      = "../../../../modules/aws/sqs"
  name        = "preprod-be-queue"
  environment = var.environment
  project     = var.project
}

// =============================================================
// Compute
// =============================================================

# Bastion Host
module "bastion_host" {
  source               = "../../../../modules/aws/ec2"
  name                 = "bastion-host"
  instance_type        = "t3.micro"
  ami_id               = data.aws_ssm_parameter.ubuntu_ami.value
  subnet_id            = module.subnets.public_subnet_ids["public-1"]
  security_group_ids   = [module.bastion_sg.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip  = true
  environment          = var.environment
  project              = var.project
}

# Strapi Server
module "strapi_server" {
  source               = "../../../../modules/aws/ec2"
  name                 = "strapi-server"
  instance_type        = "t3.medium"
  ami_id               = data.aws_ssm_parameter.ubuntu_ami.value
  subnet_id            = module.subnets.private_subnet_ids["app-1"]
  security_group_ids   = [module.app_sg.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  root_volume_size     = 50
  root_volume_type     = "gp3"
  environment          = var.environment
  project              = var.project
}

# ERP Server
module "erp_server" {
  source               = "../../../../modules/aws/ec2"
  name                 = "erp-server"
  instance_type        = "t3.xlarge"
  ami_id               = data.aws_ssm_parameter.ubuntu_ami.value
  subnet_id            = module.subnets.private_subnet_ids["app-2"]
  security_group_ids   = [module.app_sg.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  root_volume_size     = 100
  root_volume_type     = "gp3"
  environment          = var.environment
  project              = var.project
}

module "ecs_cluster" {
  source       = "../../../../modules/aws/ecs_cluster"
  cluster_name = "pre-prod-app-cluster"
  environment  = var.environment
  project      = var.project
}

module "ecs_frontend" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-frontend"
  family             = "${var.environment}-${var.project}-frontend-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.ecs_task_role.role_arn
  cpu                = "256"
  memory             = "512"
  launch_type        = "FARGATE"
  environment        = var.environment
  project            = var.project

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
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
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-frontend"
        }
      }
    }
  ])
}

module "ecs_backend" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-backend"
  family             = "${var.environment}-${var.project}-backend-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.ecs_task_role.role_arn
  cpu                = "512"
  memory             = "1024"
  launch_type        = "FARGATE"
  environment        = var.environment
  project            = var.project

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  target_group_arn = module.target_group_backend.target_group_arn
  container_name   = "backend"
  container_port   = 8080

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${module.ecr_backend.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-backend"
        }
      }
      environment = concat(
        [for k, v in var.backend_env_vars : { name = k, value = v }],
        [
          { name = "DB_HOST", value = module.rds_postgres.address },
          { name = "DB_PORT", value = tostring(module.rds_postgres.port) },
          { name = "REDIS_HOST", value = module.redis.redis_primary_endpoint },
          { name = "REDIS_PORT", value = tostring(module.redis.redis_port) },
          { name = "ERP_WEBHOOK_URL", value = module.sqs.queue_url }
        ]
      )
      secrets     = [for k, v in var.backend_secrets : { name = k, valueFrom = "${module.backend_secrets.secret_arn}:${k}::" }]
    }
  ])
}

module "ecs_saleor" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-saleor"
  family             = "${var.environment}-${var.project}-saleor-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.ecs_task_role.role_arn
  cpu                = "512"
  memory             = "1024"
  launch_type        = "FARGATE"
  environment        = var.environment
  project            = var.project

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  target_group_arn = module.target_group_saleor.target_group_arn
  container_name   = "saleor"
  container_port   = 8000

  container_definitions = jsonencode([
    {
      name      = "saleor"
      image     = "${module.ecr_saleor.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-saleor"
        }
      }
    }
  ])
}

// =============================================================
// Load Balancing
// =============================================================

module "target_group_frontend" {
  source            = "../../../../modules/aws/target_group"
  name              = "front"
  port              = 3000
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = "/"
  environment       = var.environment
  project           = var.project
}

module "target_group_backend" {
  source            = "../../../../modules/aws/target_group"
  name              = "back"
  port              = 3000
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = "/health"
  environment       = var.environment
  project           = var.project
}

module "target_group_saleor" {
  source            = "../../../../modules/aws/target_group"
  name              = "sale"
  port              = 8000
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = "/health"
  environment       = var.environment
  project           = var.project
}

module "alb" {
  source                 = "../../../../modules/aws/alb"
  name                   = "app"
  security_group_ids     = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.public_subnet_ids["public-1"],
    module.subnets.public_subnet_ids["public-2"]
  ]
  certificate_arn        = var.certificate_arn
  https_target_group_arn = module.target_group_frontend.target_group_arn
  http_default_action    = "redirect_to_https"
  http_target_group_arn  = module.target_group_frontend.target_group_arn
  environment            = var.environment
  project                = var.project
}

resource "aws_lb_listener_rule" "backend" {
  listener_arn = module.alb.https_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = module.target_group_backend.target_group_arn
  }

  condition {
    host_header {
      values = ["be-preprod.skinverse.in"]
    }
  }
}

resource "aws_lb_listener_rule" "saleor" {
  listener_arn = module.alb.https_listener_arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = module.target_group_saleor.target_group_arn
  }

  condition {
    host_header {
      values = ["saleor-preprod.skinverse.in"]
    }
  }
}

// --- Strapi ALB Configuration ---
module "target_group_strapi" {
  source               = "../../../../modules/aws/target_group"
  name                 = "strapi"
  port                 = 1337
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/_health"
  health_check_matcher = "200-399"
  environment          = var.environment
  project              = var.project
}

resource "aws_lb_target_group_attachment" "strapi" {
  target_group_arn = module.target_group_strapi.target_group_arn
  target_id        = module.strapi_server.instance_id
  port             = 1337
}

resource "aws_lb_listener_rule" "strapi" {
  listener_arn = module.alb.https_listener_arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = module.target_group_strapi.target_group_arn
  }

  condition {
    host_header {
      values = ["cms-preprod.skinverse.in"] # e.g. cms.alivewellness.com
    }
  }
}

resource "aws_lb_listener_rule" "frontend" {
  listener_arn = module.alb.https_listener_arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = module.target_group_frontend.target_group_arn
  }

  condition {
    host_header {
      values = ["fe-preprod.skinverse.in", "www.fe-preprod.skinverse.in"]
    }
  }
}

// --- ERP ALB Configuration ---
module "target_group_erp" {
  source               = "../../../../modules/aws/target_group"
  name                 = "erp"
  name_override        = "preprod-erp-tg-80"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/health" # Assuming /health is the ERP health check
  health_check_matcher = "200-399"
  environment          = var.environment
  project              = var.project
}

resource "aws_lb_target_group_attachment" "erp" {
  target_group_arn = module.target_group_erp.target_group_arn
  target_id        = module.erp_server.instance_id
  port             = 80
}

resource "aws_lb_listener_rule" "erp" {
  listener_arn = module.alb.https_listener_arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = module.target_group_erp.target_group_arn
  }

  condition {
    host_header {
      values = ["erp-preprod.skinverse.in"]
    }
  }
}
