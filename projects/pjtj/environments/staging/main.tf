terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    # Replace bucket value after running bootstrap
    bucket  = "pjtj-terraform-state-240333"
    key     = "pjtj/staging/terraform.tfstate"
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
// Compute & EC2 Setup
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
  name        = "ec2"
  environment = var.environment
  project     = var.project
  description = "Security group for staging EC2 instance allowing 80, 443, and 8000"

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

# Modular EC2 Instance (t3.xlarge, 100GB gp3, no SSH key)
module "ec2" {
  source               = "../../../../modules/aws/ec2"
  name                 = "app-server"
  ami_id               = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type        = "t3.xlarge"
  subnet_id            = module.subnets.public_subnet_ids["public-1"]
  security_group_ids   = [module.ec2_sg.security_group_id]
  key_name             = null
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
  associate_public_ip  = true
  root_volume_size     = 100
  root_volume_type     = "gp3"
  environment          = var.environment
  project              = var.project
}

# Elastic IP attached to the EC2 instance
module "ec2_eip" {
  source      = "../../../../modules/aws/eip"
  name        = "ec2-app-eip"
  instance_id = module.ec2.instance_id
  environment = var.environment
  project     = var.project
}

