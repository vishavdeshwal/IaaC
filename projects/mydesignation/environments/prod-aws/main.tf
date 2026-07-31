data "aws_availability_zones" "available" {
  state = "available"
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
  source         = "../../../../modules/aws/route_tables"
  vpc_id         = module.vpc.vpc_id
  igw_id         = module.igw.igw_id
  nat_gateway_id = module.nat_gateway.nat_gateway_id
  environment    = var.environment
  project        = var.project
}

// =============================================================
// 2. Security Groups
// =============================================================

module "sg_bastion" {
  source      = "../../../../modules/aws/security_groups"
  name        = "${var.project}-${var.environment}-bastion-sg"
  description = "Security group for Bastion Host"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project
  
  ingress_rules = []
  egress_rules  = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]
}

module "sg_ecs" {
  source      = "../../../../modules/aws/security_groups"
  name        = "${var.project}-${var.environment}-ecs-sg"
  description = "Security group for ECS Fargate Tasks"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 3001
      to_port     = 3001
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow API traffic"
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

module "sg_db" {
  source      = "../../../../modules/aws/security_groups"
  name        = "${var.project}-${var.environment}-db-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.sg_bastion.security_group_id, module.sg_ecs.security_group_id]
      description     = "Allow PG traffic from Bastion and ECS"
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

module "sg_redis" {
  source      = "../../../../modules/aws/security_groups"
  name        = "${var.project}-${var.environment}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [module.sg_ecs.security_group_id]
      description     = "Allow Redis traffic from ECS"
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
// 3. Compute (Bastion & ECS Fargate)
// =============================================================

module "iam_role_bastion" {
  source      = "../../../../modules/aws/iam_role"
  name        = "${var.project}-${var.environment}-bastion-role"
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

module "bastion" {
  source                 = "../../../../modules/aws/ec2"
  name                   = "${var.project}-${var.environment}-bastion"
  ami_id                 = "ami-0a0f1259dd1c90938"
  instance_type          = "t3.micro"
  subnet_id              = values(module.subnets.private_subnet_ids)[0]
  security_group_ids     = [module.sg_bastion.security_group_id]
  iam_instance_profile   = module.iam_role_bastion.role_name
  environment            = var.environment
  project                = var.project
}

module "ecs_cluster" {
  source       = "../../../../modules/aws/ecs_cluster"
  cluster_name = "${var.project}-${var.environment}-ecs-cluster"
  environment  = var.environment
  project      = var.project
}

module "ecs_fargate_api" {
  source             = "../../../../modules/aws/ecs_fargate"
  service_name       = "${var.project}-${var.environment}-api"
  cluster_name       = module.ecs_cluster.cluster_name
  task_family        = "${var.project}-${var.environment}-api-task"
  subnet_ids         = values(module.subnets.private_subnet_ids)
  security_group_ids = [module.sg_ecs.security_group_id]
  environment        = var.environment
  project            = var.project
  
  cpu                = 512
  memory             = 1024
  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "amazon/amazon-ecs-sample"
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
        {
          containerPort = 3001
        }
      ]
    }
  ])
}

module "ecs_fargate_worker" {
  source             = "../../../../modules/aws/ecs_fargate"
  service_name       = "${var.project}-${var.environment}-worker"
  cluster_name       = module.ecs_cluster.cluster_name
  task_family        = "${var.project}-${var.environment}-worker-task"
  subnet_ids         = values(module.subnets.private_subnet_ids)
  security_group_ids = [module.sg_ecs.security_group_id]
  environment        = var.environment
  project            = var.project
  
  cpu                = 512
  memory             = 1024
  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = "amazon/amazon-ecs-sample"
      cpu       = 512
      memory    = 1024
      essential = true
    }
  ])
}

// =============================================================
// 4. Database & Cache
// =============================================================

module "rds" {
  source                 = "../../../../modules/aws/rds"
  identifier             = "${var.project}-${var.environment}-pg"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = "db.t3.medium"
  allocated_storage      = 128
  username               = var.db_admin_username
  password               = var.db_admin_password
  security_group_ids     = [module.sg_db.security_group_id]
  subnet_ids             = values(module.subnets.private_subnet_ids)
  publicly_accessible    = false
  skip_final_snapshot    = true
  environment            = var.environment
  project                = var.project
}

module "elasticache" {
  source                 = "../../../../modules/aws/elasticache"
  name                   = "redis"
  engine                 = "redis"
  node_type              = "cache.t3.medium"
  num_cache_nodes        = 1
  security_group_ids     = [module.sg_redis.security_group_id]
  subnet_ids             = values(module.subnets.private_subnet_ids)
  environment            = var.environment
  project                = var.project
}

// =============================================================
// 5. Messaging & Queues
// =============================================================

module "sqs_dlq" {
  source      = "../../../../modules/aws/sqs"
  name        = "${var.project}-${var.environment}-dlq"
  environment = var.environment
  project     = var.project
}

module "sqs_main" {
  source            = "../../../../modules/aws/sqs"
  name              = "${var.project}-${var.environment}-queue"
  environment       = var.environment
  project           = var.project
  dlq_arn           = module.sqs_dlq.queue_arn
  max_receive_count = 5
}

// =============================================================
// 6. ECR & Storage
// =============================================================

module "ecr" {
  source      = "../../../../modules/aws/ecr"
  name        = "${var.project}-${var.environment}-repo"
  environment = var.environment
  project     = var.project
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "${var.project}-${var.environment}-app-bucket-ap-south-1"

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

// =============================================================
// 7. Secrets Manager
// =============================================================

module "secrets_manager" {
  source      = "../../../../modules/aws/secrets_manager"
  secret_name = "${var.project}-${var.environment}-secrets"
  environment = var.environment
  project     = var.project
}
