terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket       = "udc-terraform-state-672148"
    key          = "udc/staging/terraform.tfstate"
    region       = "ca-central-1"
    profile      = "udc"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ==============================================================================
# 1. NETWORKING (VPC, IGW, NAT, Subnets, Route Tables)
# ==============================================================================

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


# 2. SECURITY GROUPS
# ==============================================================================

module "alb_sg" {
  source      = "../../../../modules/aws/security_groups"
  name        = "alb-sg"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS from internet"
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

module "app_sg" {
  source      = "../../../../modules/aws/security_groups"
  name        = "app-sg"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 8080
      to_port         = 8080
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to udc-be"
    },
    {
      from_port       = 8081
      to_port         = 8081
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to udc-truedesk"
    },
    {
      from_port       = 3000
      to_port         = 3000
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to master-web"
    },
    {
      from_port       = 3001
      to_port         = 3001
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to master-admin"
    },
    {
      from_port       = 3002
      to_port         = 3002
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to student-web"
    },
    {
      from_port       = 3003
      to_port         = 3003
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP from ALB to instructor-web"
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


# 3. LOAD BALANCING (ALB, Target Groups, Listeners)
# ==============================================================================

module "alb" {
  source             = "../../../../modules/aws/alb"
  name               = "main"
  internal           = false
  subnet_ids         = values(module.subnets.public_subnet_ids)
  security_group_ids = [module.alb_sg.security_group_id]

  http_default_action   = "forward"
  http_target_group_arn = module.tg_master_web.target_group_arn

  environment = var.environment
  project     = var.project
}

# --- Target Groups ---

module "tg_be" {
  source            = "../../../../modules/aws/target_group"
  name              = "be"
  port              = 8080
  vpc_id            = module.vpc.vpc_id
  target_type       = "instance"
  use_name_prefix   = true
  health_check_path = "/api/be/health"
  environment       = var.environment
  project           = var.project
}

module "tg_truedesk" {
  source            = "../../../../modules/aws/target_group"
  name              = "truedesk"
  port              = 8081
  vpc_id            = module.vpc.vpc_id
  target_type       = "instance"
  use_name_prefix   = true
  health_check_path = "/api/truedesk/health"
  environment       = var.environment
  project           = var.project
}

module "tg_master_web" {
  source            = "../../../../modules/aws/target_group"
  name              = "master-web"
  port              = 3000
  vpc_id            = module.vpc.vpc_id
  target_type       = "instance"
  use_name_prefix   = true
  health_check_path = "/"
  environment       = var.environment
  project           = var.project
}

module "tg_master_admin" {
  source            = "../../../../modules/aws/target_group"
  name              = "master-admin"
  port              = 3001
  vpc_id            = module.vpc.vpc_id
  target_type       = "instance"
  use_name_prefix   = true
  health_check_path = "/"
  environment       = var.environment
  project           = var.project
}

module "tg_student_web" {
  source            = "../../../../modules/aws/target_group"
  name              = "student-web"
  port              = 3002
  vpc_id            = module.vpc.vpc_id
  target_type       = "instance"
  use_name_prefix   = true
  health_check_path = "/"
  environment       = var.environment
  project           = var.project
}

module "tg_instructor_web" {
  source            = "../../../../modules/aws/target_group"
  name              = "instructor-web"
  port              = 3003
  vpc_id            = module.vpc.vpc_id
  target_type       = "instance"
  use_name_prefix   = true
  health_check_path = "/"
  environment       = var.environment
  project           = var.project
}

# --- ALB Listener Rules (Path-Based Routing) ---

resource "aws_lb_listener_rule" "be" {
  listener_arn = module.alb.http_listener_arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = module.tg_be.target_group_arn
  }
  condition {
    path_pattern {
      values = ["/api/be*"]
    }
  }
}

resource "aws_lb_listener_rule" "truedesk" {
  listener_arn = module.alb.http_listener_arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = module.tg_truedesk.target_group_arn
  }
  condition {
    path_pattern {
      values = ["/api/truedesk*"]
    }
  }
}

resource "aws_lb_listener_rule" "master_admin" {
  listener_arn = module.alb.http_listener_arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = module.tg_master_admin.target_group_arn
  }
  condition {
    path_pattern {
      values = ["/admin*"]
    }
  }
}

resource "aws_lb_listener_rule" "student_web" {
  listener_arn = module.alb.http_listener_arn
  priority     = 40
  action {
    type             = "forward"
    target_group_arn = module.tg_student_web.target_group_arn
  }
  condition {
    path_pattern {
      values = ["/student*"]
    }
  }
}

resource "aws_lb_listener_rule" "instructor_web" {
  listener_arn = module.alb.http_listener_arn
  priority     = 50
  action {
    type             = "forward"
    target_group_arn = module.tg_instructor_web.target_group_arn
  }
  condition {
    path_pattern {
      values = ["/instructor*"]
    }
  }
}

# ==============================================================================
# 4. IAM ROLES & POLICIES
# ==============================================================================

# Task Execution Role (Allows ECS to pull images and write logs)
module "ecs_execution_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  environment = var.environment
  project     = var.project
}

# Task Role (Runtime permissions for containers - currently empty)
module "ecs_task_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  environment = var.environment
  project     = var.project
}

# ==============================================================================
# 5. ECR REPOSITORIES
# ==============================================================================

module "ecr_be" {
  source      = "../../../../modules/aws/ecr"
  name        = "udc-be"
  environment = var.environment
  project     = var.project
}

module "ecr_truedesk" {
  source      = "../../../../modules/aws/ecr"
  name        = "udc-truedesk"
  environment = var.environment
  project     = var.project
}

module "ecr_master_web" {
  source      = "../../../../modules/aws/ecr"
  name        = "udc-master-web"
  environment = var.environment
  project     = var.project
}

module "ecr_master_admin" {
  source      = "../../../../modules/aws/ecr"
  name        = "udc-master-admin"
  environment = var.environment
  project     = var.project
}

module "ecr_student_web" {
  source      = "../../../../modules/aws/ecr"
  name        = "udc-student-web"
  environment = var.environment
  project     = var.project
}

module "ecr_instructor_web" {
  source      = "../../../../modules/aws/ecr"
  name        = "udc-instructor-web"
  environment = var.environment
  project     = var.project
}


# ==============================================================================
# 6. ECS CLUSTER
# ==============================================================================

module "ecs_cluster" {
    source = "../../../../modules/aws/ecs_cluster"
    cluster_name = "udc-staging-cluster"
    environment = var.environment
    project = var.project
}

# --- EC2 Compute Infrastructure (ASG) ---

data "aws_ssm_parameter" "ecs_ami" {
    name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_iam_role" "ec2_instance_role" {
    name = "${var.environment}-${var.project}-ec2-instance-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = { Service = "ec2.amazonaws.com" }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "ec2_instance_role_attachment" {
    role       = aws_iam_role.ec2_instance_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
    name = "${var.environment}-${var.project}-ec2-instance-profile"
    role = aws_iam_role.ec2_instance_role.name
}

module "ecs_asg" {
    source = "../../../../modules/aws/asg"
    name   = "ecs-cluster"
    environment = var.environment
    project     = var.project
    
    ami_id = data.aws_ssm_parameter.ecs_ami.value
    instance_type = "t3.large"
    root_volume_size = 30
    
    subnet_ids = values(module.subnets.private_subnet_ids)
    security_group_ids = [module.app_sg.security_group_id]
    
    min_size         = 1
    max_size         = 3
    desired_capacity = 1
    
    iam_instance_profile_arn = aws_iam_instance_profile.ec2_instance_profile.arn
    
    user_data = base64encode(<<-EOF
      #!/bin/bash
      echo ECS_CLUSTER=${module.ecs_cluster.cluster_name} >> /etc/ecs/ecs.config
    EOF
    )
}

# ==============================================================================
# 7. ECS SERVICES (Backend & Frontend)
# ==============================================================================

module "ecs_svc_be" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-be"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "udc-be"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_be.target_group_arn
  container_name           = "udc-be"
  container_port           = 8080
  container_definitions    = var.container_def_be
  environment              = var.environment
  project                  = var.project
}

module "ecs_svc_truedesk" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-truedesk"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "udc-truedesk"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_truedesk.target_group_arn
  container_name           = "udc-truedesk"
  container_port           = 8081
  container_definitions    = var.container_def_truedesk
  environment              = var.environment
  project                  = var.project
}

module "ecs_svc_master_web" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-master-web"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "udc-master-web"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_master_web.target_group_arn
  container_name           = "udc-master-web"
  container_port           = 3000
  container_definitions    = var.container_def_master_web
  environment              = var.environment
  project                  = var.project
}

module "ecs_svc_master_admin" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-master-admin"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "udc-master-admin"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_master_admin.target_group_arn
  container_name           = "udc-master-admin"
  container_port           = 3001
  container_definitions    = var.container_def_master_admin
  environment              = var.environment
  project                  = var.project
}

module "ecs_svc_student_web" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-student-web"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "udc-student-web"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_student_web.target_group_arn
  container_name           = "udc-student-web"
  container_port           = 3002
  container_definitions    = var.container_def_student_web
  environment              = var.environment
  project                  = var.project
}

module "ecs_svc_instructor_web" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-instructor-web"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "udc-instructor-web"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_instructor_web.target_group_arn
  container_name           = "udc-instructor-web"
  container_port           = 3003
  container_definitions    = var.container_def_instructor_web
  environment              = var.environment
  project                  = var.project
}

# ==============================================================================
# 8. SQS QUEUES
# ==============================================================================

module "sqs_dlq" {
  source        = "../../../../modules/aws/sqs"
  name          = "dlq"
  name_override = "staging_UDC_DLQ"
  environment   = var.environment
  project       = var.project
}

module "sqs_queue" {
  source        = "../../../../modules/aws/sqs"
  name          = "queue"
  name_override = "staging_UDC_QUEUE"
  environment   = var.environment
  project       = var.project
  dlq_arn       = module.sqs_dlq.queue_arn
}

module "sqs_session_unlock" {
  source        = "../../../../modules/aws/sqs"
  name          = "session_unlock_queue"
  name_override = "staging_UDC_SESSION_UNLOCK_QUEUE"
  environment   = var.environment
  project       = var.project
  dlq_arn       = module.sqs_dlq.queue_arn
}
