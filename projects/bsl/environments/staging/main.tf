terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "bsl-terraform-state-148552"
    key          = "bsl/staging/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
    profile      = "bsl"
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

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

// =============================================================
// 1. Network (VPC, Subnets across 2 AZs, IGW, NAT Gateway)
// =============================================================

module "vpc" {
  source               = "../../../../modules/aws/vpc"
  vpc_cidr             = var.vpc_cidr
  environment          = var.environment
  project              = var.project
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

module "igw" {
  source      = "../../../../modules/aws/igw"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
}

module "subnets" {
  source = "../../../../modules/aws/subnets"
  vpc_id = module.vpc.vpc_id

  public_subnets = {
    for idx, cidr in var.public_subnets : "pub-${idx}" => {
      cidr     = cidr
      az_index = idx
    }
  }

  private_subnets = {
    for idx, cidr in var.private_subnets : "priv-${idx}" => {
      cidr     = cidr
      az_index = idx
    }
  }

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
  eip_allocation_id = module.nat_eip.eip_allocation_id
  public_subnet_id  = values(module.subnets.public_subnet_ids)[0]
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

// =============================================================
// 2. Security Groups
// =============================================================

module "sg_app" {
  source      = "../../../../modules/aws/security_groups"
  name        = "app"
  description = "Security group for Standalone Application EC2 Instance"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
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
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow SSH access"
    }
  ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]
}

// =============================================================
// 3. IAM Role & Standalone Application EC2 Instance (t3.xlarge)
// =============================================================

module "iam_role_app" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.project}-${var.environment}-app-role"
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
  policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  environment = var.environment
  project     = var.project
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project}-${var.environment}-app-profile"
  role = module.iam_role_app.role_name
}

module "app_server" {
  source               = "../../../../modules/aws/ec2"
  name                 = "application"
  ami_id               = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type        = "t3.xlarge"
  subnet_id            = values(module.subnets.public_subnet_ids)[0]
  associate_public_ip  = true
  root_volume_size     = 100
  root_volume_type     = "gp3"
  security_group_ids   = [module.sg_app.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.app.name
  environment          = var.environment
  project              = var.project
}

resource "aws_eip" "app" {
  instance = module.app_server.instance_id
  domain   = "vpc"

  tags = {
    Name        = "${var.environment}-${var.project}-app-eip"
    Environment = var.environment
    Project     = var.project
  }
}
