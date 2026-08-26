terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "mydesignation-prod-tfstate-ap-south-1"
    key          = "mydesignation/staging/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
    profile      = "mydsn"
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
// 1. Network (VPC, Subnets, IGW, NAT Gateway)
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
  description = "Security group for Standalone Application EC2 Instance (Nginx & Web App)"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP traffic directly to Nginx"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS traffic directly to Nginx"
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
// 3. IAM Role & Standalone Application EC2 Instance
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
  instance_type        = "t3.medium"
  subnet_id            = values(module.subnets.public_subnet_ids)[0]
  associate_public_ip  = true
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

// =============================================================
// 4. Messaging & Queues (SQS Main & DLQ)
// =============================================================

module "sqs_dlq" {
  source      = "../../../../modules/aws/sqs"
  name        = "dlq"
  environment = var.environment
  project     = var.project
}

module "sqs_main" {
  source            = "../../../../modules/aws/sqs"
  name              = "queue"
  environment       = var.environment
  project           = var.project
  dlq_arn           = module.sqs_dlq.queue_arn
  max_receive_count = 5
}

// =============================================================
// 5. Application S3 Bucket
// =============================================================

resource "aws_s3_bucket" "app_bucket" {
  bucket = "${var.project}-${var.environment}-app-bucket-ap-south-1"

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_s3_bucket_cors_configuration" "app_bucket_cors" {
  bucket = aws_s3_bucket.app_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

// =============================================================
// 6. Application IAM Permissions (S3 & SQS for App EC2)
// =============================================================

resource "aws_iam_role_policy" "app_sqs_policy" {
  name = "app-sqs-access"
  role = module.iam_role_app.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          module.sqs_main.queue_arn,
          module.sqs_dlq.queue_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_s3_policy" {
  name = "app-s3-access"
  role = module.iam_role_app.role_name

  policy = jsonencode({
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
          aws_s3_bucket.app_bucket.arn,
          "${aws_s3_bucket.app_bucket.arn}/*"
        ]
      }
    ]
  })
}
