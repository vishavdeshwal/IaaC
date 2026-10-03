terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "bsl-terraform-state-148552"
    key          = "bsl/prod/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    profile      = "bsl"
    use_lockfile = true
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

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

// =============================================================
// SECTION 1: NETWORKING (VPC, Subnets, IGW, NAT, Route Tables, S3 Gateway Endpoint)
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

module "nat_eip" {
  source      = "../../../../modules/aws/eip"
  name        = "nat-eip"
  environment = var.environment
  project     = var.project
}

module "nat_gateway" {
  source            = "../../../../modules/aws/nat_gateway"
  availability_mode = "regional"
  name_override     = "prod-bsl-regional-nat"
  public_subnet_id  = module.subnets.public_subnet_ids["public-1"]
  eip_allocation_id = module.nat_eip.eip_allocation_id
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

# --- S3 Gateway VPC Endpoint (Direct internal routing from Private Subnets to S3) ---
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.route_tables.private_route_table_id]

  tags = {
    Name        = "${var.environment}-${var.project}-s3-gateway-endpoint"
    Environment = var.environment
    Project     = var.project
  }
}

// =============================================================
// SECTION 2: SECURITY GROUPS (Strict Workload Isolation)
// =============================================================

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

module "frontend_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "frontend-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 3000
      to_port         = 3000
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to Frontend"
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

module "saleor_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "saleor-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 8000
      to_port         = 8000
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to Saleor API"
    },
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to Saleor Dashboard"
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

module "strapi_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "strapi-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 1337
      to_port         = 1337
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to Strapi"
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

module "backend_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "backend-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 4000
      to_port         = 4000
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id, module.frontend_sg.security_group_id]
      description     = "Allow HTTP to Backend Service"
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

module "erp_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "erp-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 8000
      to_port         = 8000
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to ERP"
    },
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [module.bastion_sg.security_group_id]
      description     = "Allow SSH from Bastion to ERP"
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

# --- Database & Cache Security Groups ---

module "db_saleor_strapi_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "db-saleor-strapi-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.saleor_sg.security_group_id, module.strapi_sg.security_group_id, module.bastion_sg.security_group_id]
      description     = "Allow PostgreSQL access from Saleor, Strapi, and Bastion"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow outbound"
    }
  ]
}

module "db_backend_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "db-backend-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.backend_sg.security_group_id, module.bastion_sg.security_group_id]
      description     = "Allow PostgreSQL access from Backend and Bastion"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow outbound"
    }
  ]
}

module "db_erp_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "db-erp-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [module.erp_sg.security_group_id, module.bastion_sg.security_group_id]
      description     = "Allow MariaDB access from ERP and Bastion"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow outbound"
    }
  ]
}

module "redis_backend_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "redis-backend-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [module.backend_sg.security_group_id, module.saleor_sg.security_group_id]
      description     = "Allow Redis access from Backend and Saleor"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow outbound"
    }
  ]
}

module "redis_erp_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "redis-erp-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [module.erp_sg.security_group_id]
      description     = "Allow Redis access from ERP Server"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow outbound"
    }
  ]
}

// =============================================================
// SECTION 3: SSH KEY & COMPUTE (Bastion Host & ERP Server)
// =============================================================

# --- Key Pair for Authorized SSH Access ---
resource "aws_key_pair" "auth_key" {
  count      = var.ssh_public_key != "" ? 1 : 0
  key_name   = "${var.environment}-${var.project}-ssh-key"
  public_key = var.ssh_public_key

  tags = {
    Name        = "${var.environment}-${var.project}-ssh-key"
    Environment = var.environment
    Project     = var.project
  }
}

# --- IAM Role & Instance Profile for EC2 Systems Manager ---
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
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
  environment = var.environment
  project     = var.project
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-${var.project}-ec2-profile"
  role = module.ec2_ssm_role.role_name
}

# --- 1. Bastion Host (Public Subnet) ---
module "bastion_host" {
  source               = "../../../../modules/aws/ec2"
  name                 = "bastion"
  ami_id               = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type        = var.bastion_instance_type
  subnet_id            = module.subnets.public_subnet_ids["public-1"]
  key_name             = length(aws_key_pair.auth_key) > 0 ? aws_key_pair.auth_key[0].key_name : null
  security_group_ids   = [module.bastion_sg.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip  = true
  root_volume_size     = 30
  root_volume_type     = "gp3"
  environment          = var.environment
  project              = var.project
}

module "bastion_eip" {
  source      = "../../../../modules/aws/eip"
  name        = "bastion-eip"
  instance_id = module.bastion_host.instance_id
  environment = var.environment
  project     = var.project
}

# --- 2. ERP Server (Private App Subnet) ---
module "erp_server" {
  source               = "../../../../modules/aws/ec2"
  name                 = "erp-server"
  ami_id               = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type        = var.erp_instance_type
  subnet_id            = module.subnets.private_subnet_ids["app-1"]
  key_name             = length(aws_key_pair.auth_key) > 0 ? aws_key_pair.auth_key[0].key_name : null
  security_group_ids   = [module.erp_sg.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip  = false
  root_volume_size     = var.erp_root_volume_size
  root_volume_type     = "gp3"
  environment          = var.environment
  project              = var.project
}

// =============================================================
// SECTION 4: APPLICATION LOAD BALANCER & TARGET GROUPS
// =============================================================

# --- Target Groups ---

module "target_group_frontend" {
  source              = "../../../../modules/aws/target_group"
  name                = "frontend"
  port                = 3000
  protocol            = "HTTP"
  target_type         = "ip"
  vpc_id              = module.vpc.vpc_id
  health_check_path   = "/"
  health_check_matcher = "200-399"
  environment         = var.environment
  project             = var.project
}

module "target_group_saleor" {
  source              = "../../../../modules/aws/target_group"
  name                = "saleor-api"
  port                = 8000
  protocol            = "HTTP"
  target_type         = "ip"
  vpc_id              = module.vpc.vpc_id
  health_check_path   = "/graphql/"
  health_check_matcher = "200,400,405"
  environment         = var.environment
  project             = var.project
}

module "target_group_saleor_dashboard" {
  source              = "../../../../modules/aws/target_group"
  name                = "saleor-dash"
  port                = 80
  protocol            = "HTTP"
  target_type         = "ip"
  vpc_id              = module.vpc.vpc_id
  health_check_path   = "/dashboard/"
  health_check_matcher = "200-399"
  environment         = var.environment
  project             = var.project
}

module "target_group_strapi" {
  source              = "../../../../modules/aws/target_group"
  name                = "strapi"
  port                = 1337
  protocol            = "HTTP"
  target_type         = "ip"
  vpc_id              = module.vpc.vpc_id
  health_check_path   = "/_health"
  health_check_matcher = "200,204"
  environment         = var.environment
  project             = var.project
}

module "target_group_backend" {
  source              = "../../../../modules/aws/target_group"
  name                = "backend-svc"
  port                = 4000
  protocol            = "HTTP"
  target_type         = "ip"
  vpc_id              = module.vpc.vpc_id
  health_check_path   = var.health_check_path
  health_check_matcher = "200-399"
  environment         = var.environment
  project             = var.project
}

module "target_group_erp" {
  source              = "../../../../modules/aws/target_group"
  name                = "erp"
  port                = 8000
  protocol            = "HTTP"
  target_type         = "instance"
  vpc_id              = module.vpc.vpc_id
  health_check_path   = "/"
  health_check_matcher = "200-399"
  environment         = var.environment
  project             = var.project
}

resource "aws_lb_target_group_attachment" "erp" {
  target_group_arn = module.target_group_erp.target_group_arn
  target_id        = module.erp_server.instance_id
  port             = 8000
}

# --- Application Load Balancer ---

module "alb" {
  source                  = "../../../../modules/aws/alb"
  name                    = "app"
  internal                = false
  security_group_ids      = [module.alb_sg.security_group_id]
  subnet_ids              = [
    module.subnets.public_subnet_ids["public-1"],
    module.subnets.public_subnet_ids["public-2"]
  ]
  http_port               = 80
  http_default_action     = var.certificate_arn != null ? "redirect_to_https" : "forward"
  http_target_group_arn   = module.target_group_frontend.target_group_arn
  certificate_arn         = var.certificate_arn
  https_port              = 443
  https_target_group_arn  = module.target_group_frontend.target_group_arn
  environment             = var.environment
  project                 = var.project
}

# --- ALB HTTPS Routing Rules (Host Header based) ---

resource "aws_lb_listener_rule" "saleor_api" {
  count        = var.certificate_arn != null ? 1 : 0
  listener_arn = module.alb.https_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = module.target_group_saleor.target_group_arn
  }

  condition {
    host_header {
      values = ["saleor.${var.domain_name}"]
    }
  }
}

resource "aws_lb_listener_rule" "saleor_dashboard" {
  count        = var.certificate_arn != null ? 1 : 0
  listener_arn = module.alb.https_listener_arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = module.target_group_saleor_dashboard.target_group_arn
  }

  condition {
    host_header {
      values = ["dashboard.${var.domain_name}"]
    }
  }
}

resource "aws_lb_listener_rule" "strapi" {
  count        = var.certificate_arn != null ? 1 : 0
  listener_arn = module.alb.https_listener_arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = module.target_group_strapi.target_group_arn
  }

  condition {
    host_header {
      values = ["strapi.${var.domain_name}"]
    }
  }
}

resource "aws_lb_listener_rule" "backend_api" {
  count        = var.certificate_arn != null ? 1 : 0
  listener_arn = module.alb.https_listener_arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = module.target_group_backend.target_group_arn
  }

  condition {
    host_header {
      values = ["api.${var.domain_name}"]
    }
  }
}

resource "aws_lb_listener_rule" "erp" {
  count        = var.certificate_arn != null ? 1 : 0
  listener_arn = module.alb.https_listener_arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = module.target_group_erp.target_group_arn
  }

  condition {
    host_header {
      values = ["erp.${var.domain_name}"]
    }
  }
}

// =============================================================
// SECTION 5: AWS SECRETS MANAGER, ECR & ECS (Fargate Cluster & Services)
// =============================================================

# --- 1. AWS Secrets Manager (Service-Segregated) ---

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

# --- 2. ECR Repositories ---

module "ecr_frontend" {
  source       = "../../../../modules/aws/ecr"
  name         = "frontend"
  environment  = var.environment
  project      = var.project
}

module "ecr_backend" {
  source       = "../../../../modules/aws/ecr"
  name         = "backend"
  environment  = var.environment
  project      = var.project
}

module "ecr_saleor_api" {
  source       = "../../../../modules/aws/ecr"
  name         = "saleor-api"
  environment  = var.environment
  project      = var.project
}

module "ecr_saleor_dashboard" {
  source       = "../../../../modules/aws/ecr"
  name         = "saleor-dashboard"
  environment  = var.environment
  project      = var.project
}

module "ecr_strapi" {
  source       = "../../../../modules/aws/ecr"
  name         = "strapi"
  environment  = var.environment
  project      = var.project
}

# --- 3. ECS Cluster ---

module "ecs_cluster" {
  source                    = "../../../../modules/aws/ecs_cluster"
  cluster_name              = "${var.environment}-${var.project}-cluster"
  enable_container_insights = true
  container_insights_value  = "enhanced"
  environment               = var.environment
  project                   = var.project
}

# --- 4. Service-Segregated IAM Execution Roles ---

# (A) Backend Execution Role
module "ecs_backend_execution_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-backend-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  environment = var.environment
  project     = var.project
}

resource "aws_iam_role_policy" "ecs_backend_secrets_policy" {
  name = "${var.environment}-${var.project}-ecs-backend-secrets-policy"
  role = module.ecs_backend_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [
          module.backend_secrets.secret_arn,
          "${module.backend_secrets.secret_arn}:*"
        ]
      }
    ]
  })
}

# (B) Saleor Execution Role
module "ecs_saleor_execution_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-saleor-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  environment = var.environment
  project     = var.project
}

resource "aws_iam_role_policy" "ecs_saleor_secrets_policy" {
  name = "${var.environment}-${var.project}-ecs-saleor-secrets-policy"
  role = module.ecs_saleor_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [
          module.saleor_secrets.secret_arn,
          "${module.saleor_secrets.secret_arn}:*"
        ]
      }
    ]
  })
}

# (C) Strapi Execution Role
module "ecs_strapi_execution_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-strapi-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  environment = var.environment
  project     = var.project
}

resource "aws_iam_role_policy" "ecs_strapi_secrets_policy" {
  name = "${var.environment}-${var.project}-ecs-strapi-secrets-policy"
  role = module.ecs_strapi_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [
          module.strapi_secrets.secret_arn,
          "${module.strapi_secrets.secret_arn}:*"
        ]
      }
    ]
  })
}

# (D) Frontend Execution Role
module "ecs_frontend_execution_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-frontend-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  environment = var.environment
  project     = var.project
}

# --- 5. Service Task Roles (Runtime Permissions) ---

module "ecs_backend_task_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-backend-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
  environment = var.environment
  project     = var.project
}

resource "aws_iam_role_policy" "backend_s3_sqs_task_policy" {
  name = "${var.environment}-${var.project}-backend-s3-sqs-policy"
  role = module.ecs_backend_task_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3_media.bucket_arn,
          "${module.s3_media.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          module.sqs_media_events.queue_arn
        ]
      }
    ]
  })
}

module "ecs_saleor_task_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-saleor-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
  environment = var.environment
  project     = var.project
}

resource "aws_iam_role_policy" "saleor_s3_task_policy" {
  name = "${var.environment}-${var.project}-saleor-s3-policy"
  role = module.ecs_saleor_task_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3_media.bucket_arn,
          "${module.s3_media.bucket_arn}/*"
        ]
      }
    ]
  })
}

module "ecs_strapi_task_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-strapi-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
  environment = var.environment
  project     = var.project
}

resource "aws_iam_role_policy" "strapi_s3_task_policy" {
  name = "${var.environment}-${var.project}-strapi-s3-policy"
  role = module.ecs_strapi_task_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3_media.bucket_arn,
          "${module.s3_media.bucket_arn}/*"
        ]
      }
    ]
  })
}

module "ecs_frontend_task_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-frontend-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
  environment = var.environment
  project     = var.project
}

# --- 6. ECS Fargate Services with Segregated Task Definitions ---

# 1. Saleor API
module "ecs_saleor_api" {
  source                            = "../../../../modules/aws/ecs_service"
  service_name                      = "${var.environment}-${var.project}-saleor-api"
  family                            = "${var.environment}-${var.project}-saleor-api-task"
  cluster_arn                       = module.ecs_cluster.cluster_arn
  execution_role_arn                = module.ecs_saleor_execution_role.role_arn
  task_role_arn                     = module.ecs_saleor_task_role.role_arn
  health_check_grace_period_seconds = 300
  cpu                               = "1024"
  memory                            = "2048"
  launch_type                       = "FARGATE"
  desired_count                     = 1
  environment                       = var.environment
  project                           = var.project

  security_group_ids = [module.saleor_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  target_group_arn = module.target_group_saleor.target_group_arn
  container_name   = "saleor-api"
  container_port   = 8000

  container_definitions = jsonencode([
    {
      name      = "saleor-api"
      image     = "${module.ecr_saleor_api.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      environment = concat(
        [
          { name = "DATABASE_URL", value = "postgres://${var.postgres_master_user_name}:${var.postgres_master_user_pass}@${module.rds_postgres.endpoint}/saleor" },
          { name = "REDIS_URL", value = "rediss://${module.elasticache_redis.redis_primary_endpoint}:6379" },
          { name = "AWS_MEDIA_BUCKET_NAME", value = module.s3_media.bucket_name },
          { name = "AWS_MEDIA_CUSTOM_DOMAIN", value = "media.${var.domain_name}" },
          { name = "ENABLE_MEDIA_COMPRESSION", value = "true" }
        ],
        [for k, v in var.saleor_env_vars : { name = k, value = v }]
      )
      secrets = [
        for k, v in var.saleor_secrets : {
          name      = k
          valueFrom = "${module.saleor_secrets.secret_arn}:${k}::"
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
    }
  ])
}

# 2. Saleor Worker
module "ecs_saleor_worker" {
  source             = "../../../../modules/aws/ecs_service"
  service_name       = "${var.environment}-${var.project}-saleor-worker"
  family             = "${var.environment}-${var.project}-saleor-worker-task"
  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.ecs_saleor_execution_role.role_arn
  task_role_arn      = module.ecs_saleor_task_role.role_arn
  cpu                = "512"
  memory             = "1024"
  launch_type        = "FARGATE"
  desired_count      = 1
  environment        = var.environment
  project            = var.project

  security_group_ids = [module.saleor_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]

  container_definitions = jsonencode([
    {
      name      = "saleor-worker"
      image     = "${module.ecr_saleor_api.repository_url}:latest"
      command   = ["celery", "-A", "saleor", "--app=saleor.celeryconf:app", "worker", "--loglevel=INFO", "-B"]
      essential = true
      environment = concat(
        [
          { name = "DATABASE_URL", value = "postgres://${var.postgres_master_user_name}:${var.postgres_master_user_pass}@${module.rds_postgres.endpoint}/saleor" },
          { name = "REDIS_URL", value = "rediss://${module.elasticache_redis.redis_primary_endpoint}:6379" },
          { name = "AWS_MEDIA_BUCKET_NAME", value = module.s3_media.bucket_name }
        ],
        [for k, v in var.saleor_env_vars : { name = k, value = v }]
      )
      secrets = [
        for k, v in var.saleor_secrets : {
          name      = k
          valueFrom = "${module.saleor_secrets.secret_arn}:${k}::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-saleor-worker"
        }
      }
    }
  ])
}

# 3. Saleor Dashboard
module "ecs_saleor_dashboard" {
  source                            = "../../../../modules/aws/ecs_service"
  service_name                      = "${var.environment}-${var.project}-saleor-dashboard"
  family                            = "${var.environment}-${var.project}-saleor-dashboard-task"
  cluster_arn                       = module.ecs_cluster.cluster_arn
  execution_role_arn                = module.ecs_frontend_execution_role.role_arn
  task_role_arn                     = module.ecs_frontend_task_role.role_arn
  health_check_grace_period_seconds = 120
  cpu                               = "256"
  memory                            = "512"
  launch_type                       = "FARGATE"
  desired_count                     = 1
  environment                       = var.environment
  project                           = var.project

  security_group_ids = [module.saleor_sg.security_group_id]
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
      image     = "${module.ecr_saleor_dashboard.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "API_URI", value = "https://saleor.${var.domain_name}/graphql/" }
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

# 4. Strapi CMS
module "ecs_strapi" {
  source                            = "../../../../modules/aws/ecs_service"
  service_name                      = "${var.environment}-${var.project}-strapi"
  family                            = "${var.environment}-${var.project}-strapi-task"
  cluster_arn                       = module.ecs_cluster.cluster_arn
  execution_role_arn                = module.ecs_strapi_execution_role.role_arn
  task_role_arn                     = module.ecs_strapi_task_role.role_arn
  health_check_grace_period_seconds = 180
  cpu                               = "1024"
  memory                            = "2048"
  launch_type                       = "FARGATE"
  desired_count                     = 1
  environment                       = var.environment
  project                           = var.project

  security_group_ids = [module.strapi_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  target_group_arn = module.target_group_strapi.target_group_arn
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
      environment = concat(
        [
          { name = "DATABASE_CLIENT", value = "postgres" },
          { name = "DATABASE_HOST", value = module.rds_postgres.endpoint },
          { name = "DATABASE_PORT", value = "5432" },
          { name = "DATABASE_NAME", value = "strapi" },
          { name = "DATABASE_USERNAME", value = var.postgres_master_user_name },
          { name = "DATABASE_PASSWORD", value = var.postgres_master_user_pass },
          { name = "DATABASE_SSL", value = "false" },
          { name = "AWS_BUCKET", value = module.s3_media.bucket_name },
          { name = "AWS_REGION", value = var.aws_region },
          { name = "CDN_URL", value = "https://media.${var.domain_name}" }
        ],
        [for k, v in var.strapi_env_vars : { name = k, value = v }]
      )
      secrets = [
        for k, v in var.strapi_secrets : {
          name      = k
          valueFrom = "${module.strapi_secrets.secret_arn}:${k}::"
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

# 5. Frontend App (Next.js/React)
module "ecs_frontend" {
  source                            = "../../../../modules/aws/ecs_service"
  service_name                      = "${var.environment}-${var.project}-frontend"
  family                            = "${var.environment}-${var.project}-frontend-task"
  cluster_arn                       = module.ecs_cluster.cluster_arn
  execution_role_arn                = module.ecs_frontend_execution_role.role_arn
  task_role_arn                     = module.ecs_frontend_task_role.role_arn
  health_check_grace_period_seconds = 120
  cpu                               = "1024"
  memory                            = "2048"
  launch_type                       = "FARGATE"
  desired_count                     = 1
  environment                       = var.environment
  project                           = var.project

  security_group_ids = [module.frontend_sg.security_group_id]
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
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "NEXT_PUBLIC_SALEOR_API_URL", value = "https://saleor.${var.domain_name}/graphql/" },
        { name = "NEXT_PUBLIC_STRAPI_API_URL", value = "https://strapi.${var.domain_name}" },
        { name = "NEXT_PUBLIC_BACKEND_API_URL", value = "https://api.${var.domain_name}" },
        { name = "NEXT_PUBLIC_MEDIA_URL", value = "https://media.${var.domain_name}" }
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

# 6. Backend Microservices / Core API
module "ecs_backend" {
  source                            = "../../../../modules/aws/ecs_service"
  service_name                      = "${var.environment}-${var.project}-backend"
  family                            = "${var.environment}-${var.project}-backend-task"
  cluster_arn                       = module.ecs_cluster.cluster_arn
  execution_role_arn                = module.ecs_backend_execution_role.role_arn
  task_role_arn                     = module.ecs_backend_task_role.role_arn
  health_check_grace_period_seconds = 120
  cpu                               = "1024"
  memory                            = "2048"
  launch_type                       = "FARGATE"
  desired_count                     = 1
  environment                       = var.environment
  project                           = var.project

  security_group_ids = [module.backend_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  target_group_arn = module.target_group_backend.target_group_arn
  container_name   = "backend"
  container_port   = 4000

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${module.ecr_backend.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 4000
          protocol      = "tcp"
        }
      ]
      environment = concat(
        [
          { name = "DATABASE_URL", value = "postgres://${var.backend_postgres_master_user_name}:${var.backend_postgres_master_user_pass}@${module.rds_backend_postgres.endpoint}/bslbackend" },
          { name = "REDIS_URL", value = "rediss://${module.elasticache_redis.redis_primary_endpoint}:6379" },
          { name = "S3_MEDIA_BUCKET", value = module.s3_media.bucket_name },
          { name = "CDN_BASE_URL", value = "https://media.${var.domain_name}" },
          { name = "SQS_MEDIA_QUEUE_URL", value = module.sqs_media_events.queue_url }
        ],
        [for k, v in var.backend_env_vars : { name = k, value = v }]
      )
      secrets = [
        for k, v in var.backend_secrets : {
          name      = k
          valueFrom = "${module.backend_secrets.secret_arn}:${k}::"
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
    }
  ])
}

# --- 7. ECS Autoscaling Policies ---

module "ecs_backend_autoscaling" {
  source       = "../../../../modules/aws/ecs_autoscaling"
  name         = "backend-scaling"
  cluster_name = module.ecs_cluster.cluster_name
  service_name = module.ecs_backend.service_name
  min_capacity = 1
  max_capacity = 5
  environment  = var.environment
  project      = var.project
}

module "ecs_frontend_autoscaling" {
  source       = "../../../../modules/aws/ecs_autoscaling"
  name         = "frontend-scaling"
  cluster_name = module.ecs_cluster.cluster_name
  service_name = module.ecs_frontend.service_name
  min_capacity = 1
  max_capacity = 5
  environment  = var.environment
  project      = var.project
}

module "ecs_strapi_autoscaling" {
  source       = "../../../../modules/aws/ecs_autoscaling"
  name         = "strapi-scaling"
  cluster_name = module.ecs_cluster.cluster_name
  service_name = module.ecs_strapi.service_name
  min_capacity = 1
  max_capacity = 4
  environment  = var.environment
  project      = var.project
}

module "ecs_saleor_api_autoscaling" {
  source       = "../../../../modules/aws/ecs_autoscaling"
  name         = "saleor-api-scaling"
  cluster_name = module.ecs_cluster.cluster_name
  service_name = module.ecs_saleor_api.service_name
  min_capacity = 1
  max_capacity = 5
  environment  = var.environment
  project      = var.project
}

// =============================================================
// SECTION 6: DATABASES & CACHE (Single-AZ Configuration)
// =============================================================

# --- 1. ERP MariaDB RDS (Single-AZ) ---
module "rds_mariadb" {
  source             = "../../../../modules/aws/rds"
  identifier         = "erp-mariadb"
  engine             = "mariadb"
  engine_version     = var.mariadb_engine_version
  instance_class     = var.mariadb_instance_class
  allocated_storage  = 20
  max_allocated_storage = 100
  storage_type       = "gp3"
  storage_encrypted  = true
  db_name            = "erpdb"
  username           = var.master_db_user_name
  password           = var.master_db_user_pass
  subnet_ids         = [
    module.subnets.private_subnet_ids["db-1"],
    module.subnets.private_subnet_ids["db-2"]
  ]
  security_group_ids = [module.db_erp_sg.security_group_id]
  publicly_accessible = false
  multi_az           = false
  backup_retention_period = 7
  skip_final_snapshot = false
  deletion_protection = true
  environment        = var.environment
  project            = var.project
}

# --- 2. Saleor & Strapi PostgreSQL RDS (Single-AZ) ---
module "rds_postgres" {
  source             = "../../../../modules/aws/rds"
  identifier         = "saleor-strapi-postgres"
  engine             = "postgres"
  engine_version     = var.postgres_engine_version
  instance_class     = var.postgres_instance_class
  allocated_storage  = 20
  max_allocated_storage = 100
  storage_type       = "gp3"
  storage_encrypted  = true
  db_name            = "saleor"
  username           = var.postgres_master_user_name
  password           = var.postgres_master_user_pass
  subnet_ids         = [
    module.subnets.private_subnet_ids["db-1"],
    module.subnets.private_subnet_ids["db-2"]
  ]
  security_group_ids = [module.db_saleor_strapi_sg.security_group_id]
  publicly_accessible = false
  multi_az           = false
  backup_retention_period = 7
  skip_final_snapshot = false
  deletion_protection = true
  environment        = var.environment
  project            = var.project
}

# --- 3. Backend Microservices PostgreSQL RDS (Single-AZ) ---
module "rds_backend_postgres" {
  source             = "../../../../modules/aws/rds"
  identifier         = "backend-postgres"
  engine             = "postgres"
  engine_version     = var.postgres_engine_version
  instance_class     = var.postgres_instance_class
  allocated_storage  = 20
  max_allocated_storage = 100
  storage_type       = "gp3"
  storage_encrypted  = true
  db_name            = "bslbackend"
  username           = var.backend_postgres_master_user_name
  password           = var.backend_postgres_master_user_pass
  subnet_ids         = [
    module.subnets.private_subnet_ids["db-1"],
    module.subnets.private_subnet_ids["db-2"]
  ]
  security_group_ids = [module.db_backend_sg.security_group_id]
  publicly_accessible = false
  multi_az           = false
  backup_retention_period = 7
  skip_final_snapshot = false
  deletion_protection = true
  environment        = var.environment
  project            = var.project
}

# --- 4. Backend & Saleor Redis (ElastiCache) ---
module "elasticache_redis" {
  source              = "../../../../modules/aws/elasticache"
  name                = "backend-redis"
  engine              = "redis"
  engine_version      = var.redis_engine_version
  node_type           = var.redis_node_type
  num_cache_clusters  = 1
  automatic_failover_enabled = false
  at_rest_encryption  = true
  transit_encryption  = true
  subnet_ids          = [
    module.subnets.private_subnet_ids["db-1"],
    module.subnets.private_subnet_ids["db-2"]
  ]
  security_group_ids  = [module.redis_backend_sg.security_group_id]
  environment         = var.environment
  project             = var.project
}

# --- 5. ERP Redis (ElastiCache) ---
module "elasticache_erp_redis" {
  source              = "../../../../modules/aws/elasticache"
  name                = "erp-redis"
  engine              = "redis"
  engine_version      = var.redis_engine_version
  node_type           = var.redis_node_type
  num_cache_clusters  = 1
  automatic_failover_enabled = false
  at_rest_encryption  = true
  transit_encryption  = true
  subnet_ids          = [
    module.subnets.private_subnet_ids["db-1"],
    module.subnets.private_subnet_ids["db-2"]
  ]
  security_group_ids  = [module.redis_erp_sg.security_group_id]
  environment         = var.environment
  project             = var.project
}

// =============================================================
// SECTION 7: STORAGE, CDN, EVENTBRIDGE, SQS & GUARDDUTY
// =============================================================

# --- 1. S3 Media & Assets Bucket ---
module "s3_media" {
  source                     = "../../../../modules/aws/s3"
  bucket_name                = var.media_bucket_name
  environment                = var.environment
  project                    = var.project
  manage_public_access_block = true
  block_public_acls          = true
  block_public_policy        = true
  ignore_public_acls         = true
  restrict_public_buckets    = true
  enable_cors                = true
  cors_allowed_methods       = ["GET", "HEAD", "PUT", "POST", "DELETE"]
  cors_allowed_origins       = ["https://${var.domain_name}", "https://*.${var.domain_name}"]
  cors_allowed_headers       = ["*"]
  cors_expose_headers        = ["ETag"]
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket      = module.s3_media.bucket_id
  eventbridge = true
}

# --- 2. CloudFront CDN (with Origin Access Control) ---
module "cdn" {
  source                         = "../../../../modules/aws/cloudfront"
  s3_bucket_id                   = module.s3_media.bucket_id
  s3_bucket_regional_domain_name = module.s3_media.bucket_regional_domain_name
  aliases                        = ["media.${var.domain_name}"]
  acm_certificate_arn            = var.cdn_acm_certificate_arn
  environment                    = var.environment
  project                        = var.project
}

# S3 Policy granting CloudFront OAC Read Access
resource "aws_s3_bucket_policy" "cdn_oac_access" {
  bucket = module.s3_media.bucket_id
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
        Resource = "${module.s3_media.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cdn.cloudfront_distribution_arn
          }
        }
      }
    ]
  })
}

# --- 3. SQS Queues & Dead Letter Queue for Async Media Jobs ---
module "sqs_media_events_dlq" {
  source      = "../../../../modules/aws/sqs"
  name        = "media-events-dlq"
  environment = var.environment
  project     = var.project
}

module "sqs_media_events" {
  source            = "../../../../modules/aws/sqs"
  name              = "media-events"
  dlq_arn           = module.sqs_media_events_dlq.queue_arn
  max_receive_count = 5
  environment       = var.environment
  project           = var.project
}

# Policy allowing EventBridge to send messages to SQS
resource "aws_sqs_queue_policy" "eventbridge_to_sqs" {
  queue_url = module.sqs_media_events.queue_url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgePublish"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = module.sqs_media_events.queue_arn
      }
    ]
  })
}

# --- 4. EventBridge Rule for S3 Media Object Creation ---
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "${var.environment}-${var.project}-s3-media-created"
  description = "Capture object creation events from S3 media bucket"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [module.s3_media.bucket_name]
      }
    }
  })

  tags = {
    Name        = "${var.environment}-${var.project}-s3-media-created"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_cloudwatch_event_target" "s3_created_to_sqs" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "SendToSQS"
  arn       = module.sqs_media_events.queue_arn
}

# --- 5. Amazon GuardDuty ---
resource "aws_guardduty_detector" "primary" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
  }

  tags = {
    Name        = "${var.environment}-${var.project}-guardduty"
    Environment = var.environment
    Project     = var.project
  }
}

// =============================================================
// SECTION 8: ROUTE 53 DNS RECORDS (bubkasportslab.com)
// =============================================================

data "aws_route53_zone" "primary" {
  count        = var.manage_route53_records ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

# 1. Apex Domain (bubkasportslab.com -> ALB)
resource "aws_route53_record" "apex" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# 2. WWW (www.bubkasportslab.com -> ALB)
resource "aws_route53_record" "www" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# 3. Backend API (api.bubkasportslab.com -> ALB)
resource "aws_route53_record" "api" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# 4. Saleor API (saleor.bubkasportslab.com -> ALB)
resource "aws_route53_record" "saleor" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = "saleor.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# 5. Saleor Dashboard (dashboard.bubkasportslab.com -> ALB)
resource "aws_route53_record" "dashboard" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = "dashboard.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# 6. Strapi CMS (strapi.bubkasportslab.com -> ALB)
resource "aws_route53_record" "strapi" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = "strapi.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# 7. ERP Server (erp.bubkasportslab.com -> ALB)
resource "aws_route53_record" "erp" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = "erp.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# 8. Media / Assets (media.bubkasportslab.com -> CloudFront CDN)
resource "aws_route53_record" "media" {
  count   = var.manage_route53_records ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = "media.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.cdn.cloudfront_domain_name
    zone_id                = module.cdn.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

