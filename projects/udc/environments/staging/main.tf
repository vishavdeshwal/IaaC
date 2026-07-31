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
    },
    # ECS bridge networking assigns dynamic host ports (hostPort omitted in the
    # container definitions), so the ALB reaches tasks on an ephemeral port
    # rather than the fixed service ports above. Without this the health check
    # cannot reach the task and ECS kills it.
    {
      from_port       = 32768
      to_port         = 65535
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "ALB to ECS dynamic host ports"
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
  source      = "../../../../modules/aws/target_group"
  name        = "be"
  port        = 8080
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"
  # The Go app registers GET /health at the root (cmd/server.go), not under the
  # /api/be prefix — the ALB listener rule strips nothing, and health checks go
  # straight to the task port, bypassing listener rules entirely.
  health_check_path = "/health"
  environment       = var.environment
  project           = var.project
}

module "tg_truedesk" {
  source            = "../../../../modules/aws/target_group"
  name              = "truedesk"
  port              = 8081
  vpc_id            = module.vpc.vpc_id
  target_type       = "instance"
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

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${var.environment}-${var.project}-ecs-execution-secrets"
  role = module.ecs_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["secretsmanager:GetSecretValue"]
        Effect = "Allow"
        Resource = [
          module.backend_secrets.secret_arn,
          module.frontend_secrets.secret_arn
        ]
      }
    ]
  })
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
  source       = "../../../../modules/aws/ecs_cluster"
  cluster_name = "udc-staging-cluster"
  environment  = var.environment
  project      = var.project
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
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
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
  source      = "../../../../modules/aws/asg"
  name        = "ecs-cluster"
  environment = var.environment
  project     = var.project

  ami_id           = data.aws_ssm_parameter.ecs_ami.value
  instance_type    = "t3.large"
  root_volume_size = 30

  subnet_ids         = values(module.subnets.private_subnet_ids)
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
  family                   = "${var.environment}-udc-be"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_be.target_group_arn
  container_name           = "udc-be"
  container_port           = 8080
  container_definitions = jsonencode([
    {
      name      = "udc-be"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
        }
      ]
      environment = [
        { name = "PORT", value = "8080" },
        { name = "APP_ENV", value = "production" },
        { name = "MTO_BDE_BOT_ENABLED", value = "true" },
        { name = "MTO_BDE_ANSWER_FIRST_CAR", value = "Toyota" },
        { name = "MTO_BDE_ANSWER_BIRTH_CITY", value = "Brampton" },
        { name = "MTO_BDE_ANSWER_FIRST_PET", value = "Laddum" },
        { name = "MTO_BDE_OVERALL_TIMEOUT", value = "12m" },
        { name = "MTO_BDE_STEP_TIMEOUT", value = "45s" },
        { name = "MTO_BDE_NAV_TIMEOUT", value = "60s" },
        { name = "MTO_BDE_BATCH_REPORT_PAGE_URL", value = "/desW/batchUpload/searchBatchProcessReport.do?method=view&launchFrom=fromUpdateLocationMenu&mainMenuOption=prompt.men>" },
        { name = "AWS_SQS_NOTIFICATION_URL", value = module.sqs_queue.queue_url },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "SMTP_HOST", value = "smtp.gmail.com" },
        { name = "AWS_SQS_SESSION_UNLOCK_URL", value = module.sqs_session_unlock.queue_url }
      ]
      secrets = concat([
        for k, v in var.backend_secrets : {
          name      = k
          valueFrom = "${module.backend_secrets.secret_arn}:${k}::"
        }
        ], [
        {
          name      = "MONGO_DB_INSTANCE"
          valueFrom = "${module.backend_secrets.secret_arn}:MONGO_DB_INSTANCE::"
        }
      ])
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-udc-be"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  environment = var.environment
  project     = var.project
}

module "ecs_svc_truedesk" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-truedesk"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "${var.environment}-udc-truedesk"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_truedesk.target_group_arn
  container_name           = "udc-truedesk"
  container_port           = 8081
  container_definitions = jsonencode([
    {
      name      = "udc-truedesk"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8081
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-udc-truedesk"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  environment = var.environment
  project     = var.project
}

module "ecs_svc_master_web" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-master-web"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "${var.environment}-udc-master-web"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_master_web.target_group_arn
  container_name           = "udc-master-web"
  container_port           = 3000
  container_definitions = jsonencode([
    {
      name      = "udc-master-web"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
        }
      ]
      environment = [
        { name = "NEXT_PUBLIC_API_URL", value = "http://${module.alb.alb_dns_name}/api/be/" },
        { name = "NEXT_PUBLIC_INSTRUCTOR_APP_URL", value = "http://${module.alb.alb_dns_name}/instructor/onboard/register" },
        { name = "NEXT_PUBLIC_FRANCHISE_APP_URL", value = "http://${module.alb.alb_dns_name}/admin/auth/login" },
        { name = "NEXT_PUBLIC_STUDENT_APP_SUBMIT_URL", value = "http://${module.alb.alb_dns_name}/student/locale/home" }
      ]
      secrets = [
        { name = "NEXT_PUBLIC_GOOGLE_MAPS_API_KEY", valueFrom = "${module.frontend_secrets.secret_arn}:NEXT_PUBLIC_GOOGLE_MAPS_API_KEY::" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-udc-master-web"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  environment = var.environment
  project     = var.project
}

module "ecs_svc_master_admin" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-master-admin"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "${var.environment}-udc-master-admin"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_master_admin.target_group_arn
  container_name           = "udc-master-admin"
  container_port           = 3001
  container_definitions = jsonencode([
    {
      name      = "udc-master-admin"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3001
        }
      ]
      environment = [
        { name = "NEXT_PUBLIC_API_URL", value = "http://${module.alb.alb_dns_name}/api/be/" },
        { name = "NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN", value = "udc-project-d3dd8.firebaseapp.com" },
        { name = "NEXT_PUBLIC_FIREBASE_PROJECT_ID", value = "udc-project-d3dd8" },
        { name = "NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET", value = "udc-project-d3dd8.firebasestorage.app" },
        { name = "NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID", value = "54222726004" },
        { name = "NEXT_PUBLIC_FIREBASE_APP_ID", value = "1:54222726004:web:66f6fb99616ceeb5f6c221" },
        { name = "NEXT_PUBLIC_FCM_DEVICE_PLATFORM", value = "web" },
        { name = "NEXT_PUBLIC_FRANCHISE_LOGIN_REDIRECT_URL", value = "http://${module.alb.alb_dns_name}/en/franchise?show_login=true" }
      ]
      secrets = [
        { name = "NEXT_PUBLIC_FIREBASE_API_KEY", valueFrom = "${module.frontend_secrets.secret_arn}:NEXT_PUBLIC_FIREBASE_API_KEY::" },
        { name = "NEXT_PUBLIC_FIREBASE_VAPID_KEY", valueFrom = "${module.frontend_secrets.secret_arn}:NEXT_PUBLIC_FIREBASE_VAPID_KEY_INSTRUCTOR::" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-udc-master-admin"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  environment = var.environment
  project     = var.project
}

module "ecs_svc_student_web" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-student-web"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "${var.environment}-udc-student-web"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_student_web.target_group_arn
  container_name           = "udc-student-web"
  container_port           = 3002
  container_definitions = jsonencode([
    {
      name      = "udc-student-web"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3002
        }
      ]
      environment = [
        { name = "NEXT_PUBLIC_API_URL", value = "http://${module.alb.alb_dns_name}/api/be/" },
        { name = "NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN", value = "udc-project-d3dd8.firebaseapp.com" },
        { name = "NEXT_PUBLIC_FIREBASE_PROJECT_ID", value = "udc-project-d3dd8" },
        { name = "NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET", value = "udc-project-d3dd8.firebasestorage.app" },
        { name = "NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID", value = "54222726004" },
        { name = "NEXT_PUBLIC_FIREBASE_APP_ID", value = "1:54222726004:web:66f6fb99616ceeb5f6c221" },
        { name = "NEXT_PUBLIC_PROGRAM_FORM_BASE_URL", value = "http://${module.alb.alb_dns_name}/franchise" }
      ]
      secrets = [
        { name = "NEXT_PUBLIC_FIREBASE_API_KEY", valueFrom = "${module.frontend_secrets.secret_arn}:NEXT_PUBLIC_FIREBASE_API_KEY::" },
        { name = "NEXT_PUBLIC_FIREBASE_VAPID_KEY", valueFrom = "${module.frontend_secrets.secret_arn}:NEXT_PUBLIC_FIREBASE_VAPID_KEY::" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-udc-student-web"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  environment = var.environment
  project     = var.project
}

module "ecs_svc_instructor_web" {
  source                   = "../../../../modules/aws/ecs_service"
  service_name             = "udc-instructor-web"
  launch_type              = "EC2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  family                   = "${var.environment}-udc-instructor-web"
  cluster_arn              = module.ecs_cluster.cluster_arn
  execution_role_arn       = module.ecs_execution_role.role_arn
  task_role_arn            = module.ecs_task_role.role_arn
  target_group_arn         = module.tg_instructor_web.target_group_arn
  container_name           = "udc-instructor-web"
  container_port           = 3003
  container_definitions = jsonencode([
    {
      name      = "udc-instructor-web"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3003
        }
      ]
      environment = [
        { name = "NEXT_PUBLIC_API_URL", value = "http://${module.alb.alb_dns_name}/api/be/" },
        { name = "NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN", value = "udc-project-d3dd8.firebaseapp.com" },
        { name = "NEXT_PUBLIC_FIREBASE_PROJECT_ID", value = "udc-project-d3dd8" },
        { name = "NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET", value = "udc-project-d3dd8.firebasestorage.app" },
        { name = "NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID", value = "54222726004" },
        { name = "NEXT_PUBLIC_FIREBASE_APP_ID", value = "1:54222726004:web:66f6fb99616ceeb5f6c221" },
        { name = "NEXT_PUBLIC_FCM_DEVICE_PLATFORM", value = "web" }
      ]
      secrets = [
        { name = "NEXT_PUBLIC_FIREBASE_API_KEY", valueFrom = "${module.frontend_secrets.secret_arn}:NEXT_PUBLIC_FIREBASE_API_KEY::" },
        { name = "NEXT_PUBLIC_FIREBASE_VAPID_KEY", valueFrom = "${module.frontend_secrets.secret_arn}:NEXT_PUBLIC_FIREBASE_VAPID_KEY_INSTRUCTOR::" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-udc-instructor-web"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  environment = var.environment
  project     = var.project
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

# ==============================================================================
# 9. SNS & IAM Policies
# ==============================================================================

module "sns_notifications" {
  source      = "../../../../modules/aws/sns"
  name        = "notifications"
  environment = var.environment
  project     = var.project
}

resource "aws_iam_role_policy" "ecs_task_sns_publish" {
  name = "${var.environment}-${var.project}-ecs-task-sns-publish"
  role = module.ecs_task_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["sns:Publish"]
        Effect   = "Allow"
        Resource = module.sns_notifications.topic_arn
      }
    ]
  })
}

# ==============================================================================
# 10. SES
# ==============================================================================

module "ses_email" {
  source        = "../../../../modules/aws/ses"
  email_address = var.ses_email_address
  environment   = var.environment
  project       = var.project
}

resource "aws_iam_role_policy" "ecs_task_ses_send" {
  name = "${var.environment}-${var.project}-ecs-task-ses-send"
  role = module.ecs_task_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Effect   = "Allow"
        Resource = module.ses_email.arn
      }
    ]
  })
}

# ==============================================================================
# 11. SECRETS MANAGER
# ==============================================================================

module "backend_secrets" {
  source      = "../../../../modules/aws/secrets_manager"
  secret_name = "${var.environment}-${var.project}-backend-secrets"
  secret_string = jsonencode(merge(
    var.backend_secrets,
    {
      "MONGO_DB_INSTANCE"  = "mongodb://${module.mongodb_ec2.private_ip}:27017/udc-be-v8"
      "TRUEDESK_MONGO_URI" = "mongodb://${module.mongodb_ec2.private_ip}:27017/truedesk"
    }
  ))
  recovery_window_in_days = 0 # 0 for staging, can be changed for prod
  environment             = var.environment
  project                 = var.project
}

module "frontend_secrets" {
  source                  = "../../../../modules/aws/secrets_manager"
  secret_name             = "${var.environment}-${var.project}-frontend-secrets"
  secret_string           = jsonencode(var.frontend_secrets)
  recovery_window_in_days = 0
  environment             = var.environment
  project                 = var.project
}


# ==============================================================================
# 12. DOCUMENTDB CLUSTER
# ==============================================================================

# ==============================================================================
# 13. CLOUDWATCH LOG GROUPS
# ==============================================================================

module "log_group_be" {
  source = "../../../../modules/aws/cloudwatch_log_group"
  name   = "/ecs/${var.environment}-${var.project}-udc-be"
  tags   = { Environment = var.environment, Project = var.project }
}

module "log_group_truedesk" {
  source = "../../../../modules/aws/cloudwatch_log_group"
  name   = "/ecs/${var.environment}-${var.project}-udc-truedesk"
  tags   = { Environment = var.environment, Project = var.project }
}

module "log_group_master_web" {
  source = "../../../../modules/aws/cloudwatch_log_group"
  name   = "/ecs/${var.environment}-${var.project}-udc-master-web"
  tags   = { Environment = var.environment, Project = var.project }
}

module "log_group_master_admin" {
  source = "../../../../modules/aws/cloudwatch_log_group"
  name   = "/ecs/${var.environment}-${var.project}-udc-master-admin"
  tags   = { Environment = var.environment, Project = var.project }
}

module "log_group_student_web" {
  source = "../../../../modules/aws/cloudwatch_log_group"
  name   = "/ecs/${var.environment}-${var.project}-udc-student-web"
  tags   = { Environment = var.environment, Project = var.project }
}

module "log_group_instructor_web" {
  source = "../../../../modules/aws/cloudwatch_log_group"
  name   = "/ecs/${var.environment}-${var.project}-udc-instructor-web"
  tags   = { Environment = var.environment, Project = var.project }
}

# ==============================================================================
# 9. BASTION HOST & MONGODB (EC2)
# ==============================================================================

# --- Bastion Host ---
module "bastion_sg" {
  source      = "../../../../modules/aws/security_groups"
  name        = "bastion-sg"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow SSH from anywhere"
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

module "bastion_ec2" {
  source              = "../../../../modules/aws/ec2"
  name                = "bastion"
  ami_id              = data.aws_ami.ubuntu.id
  instance_type       = "t3.micro"
  root_volume_size    = 50
  root_volume_type    = "gp3"
  subnet_id           = module.subnets.public_subnet_ids["public-1"]
  security_group_ids  = [module.bastion_sg.security_group_id]
  associate_public_ip = true
  environment         = var.environment
  project             = var.project
}

resource "aws_eip" "bastion_eip" {
  instance = module.bastion_ec2.instance_id
  domain   = "vpc"

  tags = {
    Name        = "${var.environment}-${var.project}-bastion-eip"
    Environment = var.environment
    Project     = var.project
  }
}

# --- MongoDB EC2 ---
module "mongodb_sg" {
  source      = "../../../../modules/aws/security_groups"
  name        = "mongodb-ec2-sg"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 27017
      to_port         = 27017
      protocol        = "tcp"
      security_groups = [module.app_sg.security_group_id]
      description     = "Allow MongoDB from backend tasks"
    },
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [module.bastion_sg.security_group_id]
      description     = "Allow SSH from Bastion"
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

resource "aws_iam_role" "mongodb_role" {
  name = "${var.environment}-${var.project}-mongodb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "mongodb_ssm_policy" {
  role       = aws_iam_role.mongodb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "mongodb_profile" {
  name = "${var.environment}-${var.project}-mongodb-profile"
  role = aws_iam_role.mongodb_role.name
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "mongodb_ec2" {
  source               = "../../../../modules/aws/ec2"
  name                 = "mongodb"
  ami_id               = data.aws_ami.ubuntu.id
  instance_type        = "t3.medium"
  subnet_id            = module.subnets.private_subnet_ids["db-1"]
  security_group_ids   = [module.mongodb_sg.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.mongodb_profile.name
  associate_public_ip  = false
  root_volume_size     = 100
  root_volume_type     = "gp3"
  environment          = var.environment
  project              = var.project
  additional_tags = {
    Backup = "true"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y gnupg curl
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
       gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
       --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    apt-get update
    apt-get install -y mongodb-org
    # By default mongod binds to 127.0.0.1. We need to allow all connections.
    sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
    systemctl enable mongod
    systemctl start mongod
    EOF
  )
}

# --- DLM Backup Policy ---
resource "aws_iam_role" "dlm_lifecycle_role" {
  name = "${var.environment}-${var.project}-dlm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dlm.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dlm_lifecycle_policy" {
  role       = aws_iam_role.dlm_lifecycle_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "mongodb_backup" {
  description        = "Daily backup for MongoDB EBS volumes"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags = {
      Backup = "true"
    }

    schedule {
      name = "Daily Snapshots"
      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["23:45"]
      }
      retain_rule {
        count = 7
      }
      tags_to_add = {
        SnapshotCreator = "DLM"
      }
      copy_tags = true
    }
  }
}
