terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket  = "fixxly-terraform-state-539109"
    key     = "fixxly/preprod/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
    profile = "fixxly"
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
      ENV     = "PRE-PROD"
      Project = var.project
    }
  }
}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

// =============================================================
// SECTION 1: NETWORKING (VPC, Subnets, IGW, NAT, Route Tables, SGs, ALB)
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
  source             = "../../../../modules/aws/route_tables"
  vpc_id             = module.vpc.vpc_id
  igw_id             = module.igw.igw_id
  nat_gateway_id     = module.nat_gateway.nat_gateway_id
  public_subnet_ids  = module.subnets.public_subnet_ids
  private_subnet_ids = module.subnets.private_subnet_ids
  environment        = var.environment
  project            = var.project
}

# ----------- Security Groups -----------

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
      description = "Allow SSH to Bastion"
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

module "alb_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "alb-sg"
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

module "app_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "app-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP traffic from ALB"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTPS traffic from ALB"
    },
    {
      from_port       = 1337
      to_port         = 1337
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow Strapi port from ALB"
    },
    {
      from_port       = 8000
      to_port         = 8000
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow Saleor & ERP port from ALB"
    },
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [module.bastion_sg.security_group_id]
      description     = "Allow SSH strictly from Bastion Host"
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
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [module.app_sg.security_group_id]
      description     = "Allow MariaDB access from App SG"
    },
    {
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [module.bastion_sg.security_group_id]
      description     = "Allow MariaDB access from Bastion Host"
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

module "postgres_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "postgres-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.app_sg.security_group_id]
      description     = "Allow PostgreSQL access from App SG (Strapi & Saleor)"
    },
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.bastion_sg.security_group_id]
      description     = "Allow PostgreSQL access from Bastion Host"
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

# ----------- ALB & Target Groups -----------

module "strapi_target_group" {
  source            = "../../../../modules/aws/target_group"
  name              = "strapi"
  port              = 1337
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = "/health"
  environment       = var.environment
  project           = var.project
}

module "saleor_target_group" {
  source               = "../../../../modules/aws/target_group"
  name                 = "saleor"
  port                 = 8000
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/health/"
  health_check_matcher = "200-399"
  environment          = var.environment
  project              = var.project
}

module "target_group_saleor_dashboard" {
  source            = "../../../../modules/aws/target_group"
  name              = "saledash"
  port              = 80
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = "/"
  environment       = var.environment
  project           = var.project
}

module "target_group_erp" {
  source            = "../../../../modules/aws/target_group"
  name              = "erp"
  port              = 80
  protocol          = "HTTP"
  target_type       = "instance"
  vpc_id            = module.vpc.vpc_id
  health_check_path = "/"
  environment       = var.environment
  project           = var.project
}

resource "aws_lb_target_group_attachment" "erp" {
  target_group_arn = module.target_group_erp.target_group_arn
  target_id        = module.erp_server.instance_id
  port             = 80
}

module "alb" {
  source                 = "../../../../modules/aws/alb"
  name                   = "main"
  subnet_ids             = [module.subnets.public_subnet_ids["public-1"], module.subnets.public_subnet_ids["public-2"]]
  security_group_ids     = [module.alb_sg.security_group_id]
  http_default_action    = var.certificate_arn != "" ? "redirect_to_https" : "forward"
  http_target_group_arn  = module.strapi_target_group.target_group_arn
  certificate_arn        = var.certificate_arn != "" ? var.certificate_arn : null
  https_target_group_arn = var.certificate_arn != "" ? module.strapi_target_group.target_group_arn : null
  environment            = var.environment
  project                = var.project
}

resource "aws_lb_listener_rule" "strapi_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = module.strapi_target_group.target_group_arn
  }

  condition {
    host_header {
      values = ["cms-preprod.fixxly.in"]
    }
  }
}

resource "aws_lb_listener_rule" "saleor_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = module.saleor_target_group.target_group_arn
  }

  condition {
    host_header {
      values = ["saleor-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/graphql*", "/thumbnail/*", "/.well-known/*", "/plugins/*"]
    }
  }
}

resource "aws_lb_listener_rule" "saleor_dashboard_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 25

  action {
    type             = "forward"
    target_group_arn = module.target_group_saleor_dashboard.target_group_arn
  }

  condition {
    host_header {
      values = ["saleor-preprod.fixxly.in"]
    }
  }
}

resource "aws_lb_listener_rule" "erp_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = module.target_group_erp.target_group_arn
  }

  condition {
    host_header {
      values = ["erp-preprod.fixxly.in"]
    }
  }
}

// =============================================================
// SECTION 2: COMPUTE (Bastion Host, ERP Server, ECR, ECS Cluster & Microservices)
// =============================================================

# ----------- IAM Role & Instance Profile for EC2 SSM Access -----------

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
  environment = var.environment
  project     = var.project
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = module.ec2_ssm_role.role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.environment}-${var.project}-ssm-profile"
  role = module.ec2_ssm_role.role_name
}

# ----------- Bastion Host -----------

module "bastion_host" {
  source               = "../../../../modules/aws/ec2"
  name                 = "bastion"
  ami_id               = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type        = "t3.micro"
  subnet_id            = module.subnets.public_subnet_ids["public-1"]
  security_group_ids   = [module.bastion_sg.security_group_id]
  key_name             = var.ec2_key_name != "" ? var.ec2_key_name : null
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip  = true
  root_volume_size     = 20
  root_volume_type     = "gp3"

  environment = var.environment
  project     = var.project
}

module "bastion_eip" {
  source      = "../../../../modules/aws/eip"
  name        = "bastion-eip"
  instance_id = module.bastion_host.instance_id
  environment = var.environment
  project     = var.project
}

# ----------- ERP Server (Private Subnet) -----------

module "erp_server" {
  source               = "../../../../modules/aws/ec2"
  name                 = "erp"
  ami_id               = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type        = "t3.medium"
  subnet_id            = module.subnets.private_subnet_ids["app-1"]
  security_group_ids   = [module.app_sg.security_group_id]
  key_name             = var.ec2_key_name != "" ? var.ec2_key_name : null
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip  = false
  root_volume_size     = 50
  root_volume_type     = "gp3"

  environment = var.environment
  project     = var.project
}

# ----------- ECR Repositories -----------

module "ecr_saleor" {
  source      = "../../../../modules/aws/ecr"
  name        = "saleor"
  environment = var.environment
  project     = var.project
}

module "ecr_saleor_dashboard" {
  source      = "../../../../modules/aws/ecr"
  name        = "saleor-dashboard"
  environment = var.environment
  project     = var.project
}

module "ecr_strapi" {
  source      = "../../../../modules/aws/ecr"
  name        = "strapi"
  environment = var.environment
  project     = var.project
}

# ----------- ECS Cluster & Microservices -----------

module "ecs_cluster" {
  source       = "../../../../modules/aws/ecs_cluster"
  cluster_name = "${var.environment}-${var.project}-cluster"
  environment  = var.environment
  project      = var.project
}

# IAM Execution & Task Roles
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

resource "aws_iam_role_policy" "ecs_secretsmanager_execution_policy" {
  name = "${var.environment}-${var.project}-ecs-secretsmanager-exec-policy"
  role = module.ecs_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          module.saleor_secrets.secret_arn,
          module.backend_secrets.secret_arn,
          module.strapi_secrets.secret_arn
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

resource "aws_iam_role_policy" "ecs_secretsmanager_task_policy" {
  name = "${var.environment}-${var.project}-ecs-secretsmanager-task-policy"
  role = module.ecs_task_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          module.saleor_secrets.secret_arn,
          module.backend_secrets.secret_arn,
          module.strapi_secrets.secret_arn
        ]
      }
    ]
  })
}

# ----------- Public S3 Media Bucket for Saleor & Strapi -----------

module "s3_media" {
  source                     = "../../../../modules/aws/s3"
  bucket_name                = "${var.environment}-${var.project}-saleor-strapi-media"
  enable_public_read         = true
  manage_public_access_block = true
  block_public_acls          = false
  block_public_policy        = false
  ignore_public_acls         = false
  restrict_public_buckets    = false
  enable_cors                = true
  environment                = var.environment
  project                    = var.project
}

resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "${var.environment}-${var.project}-ecs-task-s3-policy"
  role = module.ecs_task_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = module.s3_media.bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${module.s3_media.bucket_arn}/*"
      }
    ]
  })
}

locals {
  saleor_container_secrets = [for k, v in var.saleor_secrets : { name = k, valueFrom = "${module.saleor_secrets.secret_arn}:${k}::" }]
  saleor_container_env = concat(
    [for k, v in var.saleor_env_vars : { name = k, value = v }]
  )
}

# 1. Saleor API Service
module "ecs_saleor_api" {
  source                            = "../../../../modules/aws/ecs_service"
  enable_execute_command            = true
  service_name                      = "${var.environment}-${var.project}-saleor-api"
  family                            = "${var.environment}-${var.project}-saleor-api-task"
  cluster_arn                       = module.ecs_cluster.cluster_arn
  execution_role_arn                = module.ecs_execution_role.role_arn
  task_role_arn                     = module.ecs_task_role.role_arn
  health_check_grace_period_seconds = 300
  cpu                               = "512"
  memory                 = "1024"
  launch_type            = "FARGATE"
  environment            = var.environment
  project                = var.project

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  target_group_arn = module.saleor_target_group.target_group_arn
  container_name   = "saleor-api"
  container_port   = 8000

  container_definitions = jsonencode([
    {
      name      = "saleor-api"
      image     = "${module.ecr_saleor.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-saleor-api"
        }
      }
      environment = local.saleor_container_env
      secrets     = local.saleor_container_secrets
    }
  ])
}

# 2. Saleor Worker Service (Celery Worker)
module "ecs_saleor_worker" {
  source             = "../../../../modules/aws/ecs_service"
  platform_version   = "1.4.0"
  service_name       = "${var.environment}-${var.project}-saleor-worker"
  family             = "${var.environment}-${var.project}-saleor-worker-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.ecs_task_role.role_arn
  cpu                = "512"
  memory             = "1024"
  launch_type        = "FARGATE"
  environment        = var.environment
  project            = var.project
  desired_count      = 1

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]

  container_definitions = jsonencode([
    {
      name      = "saleor-worker"
      image     = "${module.ecr_saleor.repository_url}:latest"
      command   = ["celery", "--app", "saleor.celeryconf:app", "worker", "-E", "--loglevel=info"]
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-saleor-worker"
        }
      }
      environment = local.saleor_container_env
      secrets     = local.saleor_container_secrets
    }
  ])
}

# 3. Saleor Beat Service (Celery Scheduler)
module "ecs_saleor_beat" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-saleor-beat"
  family             = "${var.environment}-${var.project}-saleor-beat-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.ecs_execution_role.role_arn
  task_role_arn      = module.ecs_task_role.role_arn
  cpu                = "512"
  memory             = "1024"
  launch_type        = "FARGATE"
  environment        = var.environment
  project            = var.project
  desired_count      = 1

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
  availability_zone_rebalancing      = "DISABLED"

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]

  container_definitions = jsonencode([
    {
      name      = "saleor-beat"
      image     = "${module.ecr_saleor.repository_url}:latest"
      command   = ["celery", "--app", "saleor.celeryconf:app", "beat", "--scheduler", "saleor.schedulers.schedulers.DatabaseScheduler"]
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-saleor-beat"
        }
      }
      environment = local.saleor_container_env
      secrets     = local.saleor_container_secrets
    }
  ])
}

# 4. Saleor Dashboard Service
module "ecs_saleor_dashboard" {
  source                            = "../../../../modules/aws/ecs_service"
  service_name                      = "${var.environment}-${var.project}-saleor-dashboard"
  family                            = "${var.environment}-${var.project}-saleor-dashboard-task"
  cluster_arn                       = module.ecs_cluster.cluster_arn
  execution_role_arn                = module.ecs_execution_role.role_arn
  task_role_arn                     = module.ecs_task_role.role_arn
  health_check_grace_period_seconds = 300
  cpu                               = "256"
  memory                            = "512"
  launch_type                       = "FARGATE"
  environment                       = var.environment
  project                           = var.project
  desired_count                     = 1

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  target_group_arn = module.target_group_saleor_dashboard.target_group_arn
  container_name   = "saleor-dashboard"
  container_port   = 80

  container_definitions = jsonencode([
    {
      name      = "saleor-dashboard"
      image     = "ghcr.io/saleor/saleor-dashboard:3.23"
      essential = true
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-saleor-dashboard"
        }
      }
    }
  ])
}

# 5. Strapi Service
module "ecs_strapi" {
  source                            = "../../../../modules/aws/ecs_service"
  service_name                      = "${var.environment}-${var.project}-strapi"
  family                            = "${var.environment}-${var.project}-strapi-task"
  cluster_arn                       = module.ecs_cluster.cluster_arn
  execution_role_arn                = module.ecs_execution_role.role_arn
  task_role_arn                     = module.ecs_task_role.role_arn
  health_check_grace_period_seconds = 300
  cpu                               = "512"
  memory             = "1024"
  launch_type        = "FARGATE"
  environment        = var.environment
  project            = var.project
  desired_count      = 1

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  target_group_arn = module.strapi_target_group.target_group_arn
  container_name   = "strapi"
  container_port   = 1337

  container_definitions = jsonencode([
    {
      name      = "strapi"
      image     = "${module.ecr_strapi.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 1337
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-strapi"
        }
      }
    }
  ])
}

// =============================================================
// SECTION 3: DATABASE & CACHE (RDS MariaDB, RDS PostgreSQL, ElastiCache Redis)
// =============================================================

# ----------- RDS MariaDB -----------

module "rds_mariadb" {
  source             = "../../../../modules/aws/rds"
  identifier         = "mariadb"
  engine             = "mariadb"
  engine_version     = var.mariadb_engine_version
  instance_class     = "db.m5.xlarge"
  allocated_storage  = 100
  storage_type       = "gp3"
  db_name            = "fixxlydb"
  username           = var.master_db_user_name
  password           = var.master_db_user_pass
  subnet_ids         = [module.subnets.private_subnet_ids["db-1"], module.subnets.private_subnet_ids["db-2"]]
  security_group_ids = [module.db_sg.security_group_id]

  environment = var.environment
  project     = var.project
}

# ----------- RDS PostgreSQL (for Saleor & Strapi) -----------

module "rds_postgres" {
  source             = "../../../../modules/aws/rds"
  identifier         = "saleor-strapi"
  engine             = "postgres"
  engine_version     = var.postgres_engine_version
  instance_class     = "db.m5.large"
  allocated_storage  = 100
  storage_type       = "gp3"
  db_name            = "fixxlypostgres"
  username           = var.postgres_master_user_name
  password           = var.postgres_master_user_pass
  subnet_ids         = [module.subnets.private_subnet_ids["db-1"], module.subnets.private_subnet_ids["db-2"]]
  security_group_ids = [module.postgres_sg.security_group_id]

  environment = var.environment
  project     = var.project
}

# ----------- ElastiCache Redis -----------

module "elasticache_redis" {
  source             = "../../../../modules/aws/elasticache"
  name               = "redis"
  engine             = "redis"
  engine_version     = "7.0"
  node_type          = "cache.t4g.micro"
  subnet_ids         = [module.subnets.private_subnet_ids["db-1"], module.subnets.private_subnet_ids["db-2"]]
  security_group_ids = [module.redis_sg.security_group_id]

  environment = var.environment
  project     = var.project
}

// =============================================================
// SECTION 4: SECURITY & SECRETS MANAGER
// =============================================================

module "backend_secrets" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}-${var.project}-backend-secrets"
  secret_string = jsonencode(var.backend_secrets)
  environment   = var.environment
  project       = var.project
}

module "saleor_secrets" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}-${var.project}-saleor-secrets"
  secret_string = jsonencode(var.saleor_secrets)
  environment   = var.environment
  project       = var.project
}

module "strapi_secrets" {
  source        = "../../../../modules/aws/secrets_manager"
  secret_name   = "${var.environment}-${var.project}-strapi-secrets"
  secret_string = jsonencode(var.strapi_secrets)
  environment   = var.environment
  project       = var.project
}
