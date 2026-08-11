terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket  = "pjtj-terraform-state-240333"
    key     = "pjtj/prod/terraform.tfstate"
    region  = "ap-south-1"
    profile = "pjtj"
    encrypt = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Environment = upper(var.environment)
      Project     = var.project
    }
  }
}

// =============================================================
// VPC & Networking
// =============================================================

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
  source             = "../../../../modules/aws/route_tables"
  vpc_id             = module.vpc.vpc_id
  igw_id             = module.igw.igw_id
  nat_gateway_id     = module.nat_gateway.nat_gateway_id
  environment        = var.environment
  project            = var.project
  public_subnet_ids  = module.subnets.public_subnet_ids
  private_subnet_ids = module.subnets.private_subnet_ids
}

// =============================================================
// Compute & EC2 ERP Server (50 GB gp3, t3.xlarge, EIP)
// =============================================================

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# IAM Role for SSM Connect (Keyless SSH alternative)
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

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${var.environment}-${var.project}-ec2-ssm-profile"
  role = module.ec2_ssm_role.role_name
}

# Security Group allowing ports 80, 443, 8000
module "ec2_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "erp-server"
  environment = var.environment
  project     = var.project
  description = "Security group for prod EC2 ERP server allowing 80, 443, and 8000"

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP traffic"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP traffic"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS traffic"
    },
    {
      from_port   = 8000
      to_port     = 8000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow port 8000 traffic"
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

# Modular EC2 Instance (t3.xlarge, 50GB gp3, no SSH key)
module "ec2" {
  source               = "../../../../modules/aws/ec2"
  name                 = "erp-server"
  ami_id               = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type        = "t3.xlarge"
  subnet_id            = module.subnets.public_subnet_ids["public-1"]
  security_group_ids   = [module.ec2_sg.security_group_id]
  key_name             = null
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
  associate_public_ip  = true
  root_volume_size     = 50
  root_volume_type     = "gp3"
  environment          = var.environment
  project              = var.project
}

# Elastic IP attached to the EC2 instance
module "ec2_eip" {
  source      = "../../../../modules/aws/eip"
  name        = "erp-server-eip"
  instance_id = module.ec2.instance_id
  environment = var.environment
  project     = var.project
}

// =============================================================
// Database: MariaDB (100 GB gp3, Single Instance)
// =============================================================

# Security Group for MariaDB allowing traffic from EC2 ERP server
module "mariadb_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "mariadb"
  environment = var.environment
  project     = var.project
  description = "Security group for MariaDB allowing access from EC2 ERP server"

  ingress_rules = [
    {
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [module.ec2_sg.security_group_id]
      description     = "Allow MariaDB traffic from EC2 ERP server"
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

# MariaDB Parameter Group
resource "aws_db_parameter_group" "mariadb_params" {
  name   = lower("${var.environment}-${var.project}-mariadb11-4")
  family = "mariadb11.4"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }
}

# MariaDB RDS Instance (Single node, 100 GB gp3, db-1/db-2 subnets)
module "rds_mariadb" {
  source               = "../../../../modules/aws/rds"
  identifier           = "mariadb"
  engine               = "mariadb"
  engine_version       = "11.4"
  instance_class       = "db.m5.xlarge"
  allocated_storage    = 100
  storage_type         = "gp3"
  multi_az             = false
  username             = var.mariadb_user_name
  password             = var.mariadb_user_pass
  apply_immediately    = true
  parameter_group_name = aws_db_parameter_group.mariadb_params.name
  subnet_ids = [
    module.subnets.private_subnet_ids["db-1"],
    module.subnets.private_subnet_ids["db-2"]
  ]
  security_group_ids = [module.mariadb_sg.security_group_id]
  environment        = var.environment
  project            = var.project
}

// =============================================================
// Cache: ElastiCache Redis (Single Node Cluster, db-1/db-2 subnets)
// =============================================================

# Security Group for Redis allowing traffic from EC2 ERP server
module "redis_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "redis"
  environment = var.environment
  project     = var.project
  description = "Security group for Redis allowing access from EC2 ERP server"

  ingress_rules = [
    {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [module.ec2_sg.security_group_id]
      description     = "Allow Redis traffic from EC2 ERP server"
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

# ElastiCache Redis (1 node cluster, transit_encryption = false, db-1/db-2 subnets)
module "redis" {
  source             = "../../../../modules/aws/elasticache"
  name               = "redis"
  engine             = "redis"
  node_type          = "cache.t3.small"
  num_cache_clusters = 1
  transit_encryption = false
  apply_immediately  = true
  subnet_ids = [
    module.subnets.private_subnet_ids["db-1"],
    module.subnets.private_subnet_ids["db-2"]
  ]
  security_group_ids = [module.redis_sg.security_group_id]
  environment        = var.environment
  project            = var.project
}

