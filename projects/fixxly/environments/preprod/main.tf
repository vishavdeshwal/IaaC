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
      from_port       = 3000
      to_port         = 3000
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow HTTP traffic from ALB"
    },
    {
      from_port   = 3000
      to_port     = 3025
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "Allow inter-service backend communication within VPC"
    },
    {
      from_port   = 1337
      to_port     = 1337
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "Allow Strapi port from VPC"
    },
    {
      from_port       = 1337
      to_port         = 1337
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Allow Strapi port from ALB"
    },
    {
      from_port   = 8000
      to_port     = 8000
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "Allow Saleor port from VPC"
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

module "msk_sg" {
  source      = "../../../../modules/aws/security_groups"
  vpc_id      = module.vpc.vpc_id
  name        = "msk-sg"
  environment = var.environment
  project     = var.project

  ingress_rules = [
    {
      from_port       = 9092
      to_port         = 9092
      protocol        = "tcp"
      security_groups = [module.app_sg.security_group_id]
      description     = "Allow Plaintext Kafka traffic from App SG"
    },
    {
      from_port       = 9094
      to_port         = 9094
      protocol        = "tcp"
      security_groups = [module.app_sg.security_group_id]
      description     = "Allow TLS Kafka traffic from App SG"
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
  source               = "../../../../modules/aws/target_group"
  name                 = "strapi"
  port                 = 1337
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/_health"
  health_check_matcher = "200-299"
  environment          = var.environment
  project              = var.project
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

# --- Microservices & Frontend Target Groups ---

module "target_group_frontend" {
  source            = "../../../../modules/aws/target_group"
  name              = "frontend"
  port              = var.frontend_port
  protocol          = "HTTP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc_id
  health_check_path = "/"
  environment       = var.environment
  project           = var.project
}

module "target_group_bff" {
  source               = "../../../../modules/aws/target_group"
  name                 = "bff"
  port                 = var.consumer_bff_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/health"
  health_check_matcher = "200,404"
  environment          = var.environment
  project              = var.project
}

module "target_group_payment" {
  source               = "../../../../modules/aws/target_group"
  name                 = "payment"
  port                 = var.payment_service_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/health"
  health_check_matcher = "200,404"
  environment          = var.environment
  project              = var.project
}

module "target_group_erp_sync" {
  source               = "../../../../modules/aws/target_group"
  name                 = "erpsync"
  port                 = var.erp_sync_service_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/health"
  health_check_matcher = "200,404"
  environment          = var.environment
  project              = var.project
}

module "target_group_product" {
  source               = "../../../../modules/aws/target_group"
  name                 = "product"
  port                 = var.product_service_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/health"
  health_check_matcher = "200,404"
  environment          = var.environment
  project              = var.project
}

module "target_group_inventory" {
  source               = "../../../../modules/aws/target_group"
  name                 = "inventory"
  port                 = var.inventory_service_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/health"
  health_check_matcher = "200,404"
  environment          = var.environment
  project              = var.project
}

module "target_group_cart" {
  source               = "../../../../modules/aws/target_group"
  name                 = "cart"
  port                 = var.cart_service_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/health"
  health_check_matcher = "200,404"
  environment          = var.environment
  project              = var.project
}

module "target_group_coupon" {
  source               = "../../../../modules/aws/target_group"
  name                 = "coupon"
  port                 = var.coupon_service_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/health"
  health_check_matcher = "200,404"
  environment          = var.environment
  project              = var.project
}

module "target_group_serviceability" {
  source               = "../../../../modules/aws/target_group"
  name                 = "srvability"
  port                 = var.serviceability_service_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/health"
  health_check_matcher = "200,404"
  environment          = var.environment
  project              = var.project
}

module "target_group_referral" {
  source               = "../../../../modules/aws/target_group"
  name                 = "referral"
  port                 = var.referral_service_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  health_check_path    = "/healthz"
  health_check_matcher = "200,404"
  environment          = var.environment
  project              = var.project
}

module "alb" {
  source                 = "../../../../modules/aws/alb"
  name                   = "main"
  subnet_ids             = [module.subnets.public_subnet_ids["public-1"], module.subnets.public_subnet_ids["public-2"]]
  security_group_ids     = [module.alb_sg.security_group_id]
  http_default_action    = var.certificate_arn != "" ? "redirect_to_https" : "forward"
  http_target_group_arn  = module.strapi_target_group.target_group_arn
  certificate_arn        = var.certificate_arn != "" ? var.certificate_arn : null
  https_target_group_arn = var.certificate_arn != "" ? module.target_group_frontend.target_group_arn : null
  environment            = var.environment
  project                = var.project
}

resource "aws_lb_listener_rule" "frontend_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = module.target_group_frontend.target_group_arn
  }

  condition {
    host_header {
      values = ["fe-preprod.fixxly.in"]
    }
  }
}

resource "aws_lb_listener_rule" "strapi_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 2

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
  priority     = 3

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
  priority     = 4

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
  priority     = 5

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

# --- api-preprod.fixxly.in Path-Based Rules ---

resource "aws_lb_listener_rule" "payment_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = module.target_group_payment.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/payments/webhooks/pg/cashfree*"]
    }
  }
}

resource "aws_lb_listener_rule" "erp_sync_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = module.target_group_erp_sync.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/erp/webhooks/erpnext*"]
    }
  }
}

resource "aws_lb_listener_rule" "saleor_webhook_erp_sync_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 21

  action {
    type             = "forward"
    target_group_arn = module.target_group_erp_sync.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/erp/webhooks/saleor*"]
    }
  }
}

resource "aws_lb_listener_rule" "product_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = module.target_group_product.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/erp/products*", "/api/v1/erp/categories*", "/api/v1/erp/product-types*"]
    }
  }
}

resource "aws_lb_listener_rule" "saleor_webhook_product_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 35

  action {
    type             = "forward"
    target_group_arn = module.target_group_product.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/saleor/webhooks/*"]
    }
  }
}

resource "aws_lb_listener_rule" "inventory_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = module.target_group_inventory.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/erp/stock*"]
    }
  }
}

resource "aws_lb_listener_rule" "cart_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = module.target_group_cart.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/erp/delivery-policy*"]
    }
  }
}

resource "aws_lb_listener_rule" "coupon_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 60

  action {
    type             = "forward"
    target_group_arn = module.target_group_coupon.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/coupons/admin*"]
    }
  }
}

resource "aws_lb_listener_rule" "serviceability_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 70

  action {
    type             = "forward"
    target_group_arn = module.target_group_serviceability.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/admin/serviceability*"]
    }
  }
}

resource "aws_lb_listener_rule" "referral_erp_webhook_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 25

  action {
    type             = "forward"
    target_group_arn = module.target_group_referral.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/referral/erp/webhooks/*", "/referral/erp/webhooks/*"]
    }
  }
}

resource "aws_lb_listener_rule" "bff_rule" {
  listener_arn = module.alb.https_listener_arn
  priority     = 5000

  action {
    type             = "forward"
    target_group_arn = module.target_group_bff.target_group_arn
  }

  condition {
    host_header {
      values = ["api-preprod.fixxly.in"]
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

module "ecr_frontend" {
  source      = "../../../../modules/aws/ecr"
  name        = "frontend"
  environment = var.environment
  project     = var.project
}

module "ecr_consumer_bff" {
  source      = "../../../../modules/aws/ecr"
  name        = "consumer-bff"
  environment = var.environment
  project     = var.project
}

module "ecr_auth_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "auth-service"
  environment = var.environment
  project     = var.project
}

module "ecr_product_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "product-service"
  environment = var.environment
  project     = var.project
}

module "ecr_order_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "order-service"
  environment = var.environment
  project     = var.project
}

module "ecr_cart_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "cart-service"
  environment = var.environment
  project     = var.project
}

module "ecr_inventory_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "inventory-service"
  environment = var.environment
  project     = var.project
}

module "ecr_cms_bridge" {
  source      = "../../../../modules/aws/ecr"
  name        = "cms-bridge"
  environment = var.environment
  project     = var.project
}

module "ecr_coupon_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "coupon-service"
  environment = var.environment
  project     = var.project
}

module "ecr_notification_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "notification-service"
  environment = var.environment
  project     = var.project
}

module "ecr_payment_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "payment-service"
  environment = var.environment
  project     = var.project
}

module "ecr_erp_sync_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "erp-sync-service"
  environment = var.environment
  project     = var.project
}

module "ecr_wallet_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "wallet-service"
  environment = var.environment
  project     = var.project
}

module "ecr_assets_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "assets-service"
  environment = var.environment
  project     = var.project
}

module "ecr_serviceability_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "serviceability-service"
  environment = var.environment
  project     = var.project
}

module "ecr_referral_service" {
  source      = "../../../../modules/aws/ecr"
  name        = "referral-service"
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

# AWS Cloud Map Private DNS Namespace for Service Discovery
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name        = "${var.environment}.${var.project}.internal"
  description = "Private Service Discovery DNS Namespace for ${var.environment}-${var.project} Microservices"
  vpc         = module.vpc.vpc_id
}

# Dedicated Backend IAM Execution & Task Roles
module "ecs_backend_execution_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-backend-exec-role"
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

resource "aws_iam_role_policy_attachment" "ecs_backend_execution_policy" {
  role       = module.ecs_backend_execution_role.role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_backend_cloudwatch_exec_policy" {
  name = "${var.environment}-${var.project}-ecs-backend-cloudwatch-exec-policy"
  role = module.ecs_backend_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_backend_secretsmanager_exec_policy" {
  name = "${var.environment}-${var.project}-ecs-backend-secretsmanager-exec-policy"
  role = module.ecs_backend_execution_role.role_name

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
          module.backend_secrets.secret_arn,
          "${module.backend_secrets.secret_arn}:*"
        ]
      }
    ]
  })
}

module "ecs_backend_task_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-backend-task-role"
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

# AWS Bedrock Invocation Policy for Consumer BFF & Backend Microservices
resource "aws_iam_policy" "bedrock_policy" {
  name        = "${var.environment}-${var.project}-bedrock-policy"
  description = "Allows microservices to invoke AWS Bedrock models"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvokePermissions"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_backend_bedrock_task_policy" {
  role       = module.ecs_backend_task_role.role_name
  policy_arn = aws_iam_policy.bedrock_policy.arn
}


resource "aws_iam_role_policy" "ecs_backend_secretsmanager_task_policy" {
  name = "${var.environment}-${var.project}-ecs-backend-secretsmanager-task-policy"
  role = module.ecs_backend_task_role.role_name

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
          module.backend_secrets.secret_arn,
          "${module.backend_secrets.secret_arn}:*"
        ]
      }
    ]
  })
}

# Dedicated Frontend IAM Execution & Task Roles
module "ecs_frontend_execution_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-frontend-exec-role"
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

resource "aws_iam_role_policy_attachment" "ecs_frontend_execution_policy" {
  role       = module.ecs_frontend_execution_role.role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_frontend_cloudwatch_exec_policy" {
  name = "${var.environment}-${var.project}-ecs-frontend-cloudwatch-exec-policy"
  role = module.ecs_frontend_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
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

# Dedicated Saleor IAM Execution & Task Roles
module "ecs_saleor_execution_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-saleor-exec-role"
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

resource "aws_iam_role_policy_attachment" "ecs_saleor_execution_policy" {
  role       = module.ecs_saleor_execution_role.role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_saleor_cloudwatch_exec_policy" {
  name = "${var.environment}-${var.project}-ecs-saleor-cloudwatch-exec-policy"
  role = module.ecs_saleor_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_saleor_secretsmanager_exec_policy" {
  name = "${var.environment}-${var.project}-ecs-saleor-secretsmanager-exec-policy"
  role = module.ecs_saleor_execution_role.role_name

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
          module.saleor_secrets.secret_arn
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

resource "aws_iam_role_policy" "ecs_saleor_secretsmanager_task_policy" {
  name = "${var.environment}-${var.project}-ecs-saleor-secretsmanager-task-policy"
  role = module.ecs_saleor_task_role.role_name

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
          module.saleor_secrets.secret_arn
        ]
      }
    ]
  })
}

# Dedicated Strapi IAM Execution & Task Roles
module "ecs_strapi_execution_role" {
  source = "../../../../modules/aws/iam_role"
  name   = "${var.environment}-${var.project}-ecs-strapi-exec-role"
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

resource "aws_iam_role_policy_attachment" "ecs_strapi_execution_policy" {
  role       = module.ecs_strapi_execution_role.role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_strapi_cloudwatch_exec_policy" {
  name = "${var.environment}-${var.project}-ecs-strapi-cloudwatch-exec-policy"
  role = module.ecs_strapi_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_strapi_secretsmanager_exec_policy" {
  name = "${var.environment}-${var.project}-ecs-strapi-secretsmanager-exec-policy"
  role = module.ecs_strapi_execution_role.role_name

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
          module.strapi_secrets.secret_arn
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

resource "aws_iam_role_policy" "ecs_strapi_secretsmanager_task_policy" {
  name = "${var.environment}-${var.project}-ecs-strapi-secretsmanager-task-policy"
  role = module.ecs_strapi_task_role.role_name

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

# ----------- Private S3 Bucket for Saleor & Strapi -----------

module "s3_private_media" {
  source                     = "../../../../modules/aws/s3"
  bucket_name                = "${var.environment}-${var.project}-saleor-strapi-private-bucket"
  enable_public_read         = false
  manage_public_access_block = true
  block_public_acls          = true
  block_public_policy        = true
  ignore_public_acls         = true
  restrict_public_buckets    = true
  enable_cors                = false
  environment                = var.environment
  project                    = var.project
}

resource "aws_iam_role_policy" "ecs_saleor_task_s3_policy" {
  name = "${var.environment}-${var.project}-ecs-saleor-task-s3-policy"
  role = module.ecs_saleor_task_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          module.s3_media.bucket_arn,
          module.s3_private_media.bucket_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "${module.s3_media.bucket_arn}/*",
          "${module.s3_private_media.bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_strapi_task_s3_policy" {
  name = "${var.environment}-${var.project}-ecs-strapi-task-s3-policy"
  role = module.ecs_strapi_task_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          module.s3_media.bucket_arn,
          module.s3_private_media.bucket_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "${module.s3_media.bucket_arn}/*",
          "${module.s3_private_media.bucket_arn}/*"
        ]
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
  execution_role_arn                = module.ecs_saleor_execution_role.role_arn
  task_role_arn                     = module.ecs_saleor_task_role.role_arn
  health_check_grace_period_seconds = 300
  cpu                               = "512"
  memory                            = "1024"
  launch_type                       = "FARGATE"
  environment                       = var.environment
  project                           = var.project

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
  execution_role_arn = module.ecs_saleor_execution_role.role_arn
  task_role_arn      = module.ecs_saleor_task_role.role_arn
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
  execution_role_arn = module.ecs_saleor_execution_role.role_arn
  task_role_arn      = module.ecs_saleor_task_role.role_arn
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
  execution_role_arn                = module.ecs_saleor_execution_role.role_arn
  task_role_arn                     = module.ecs_saleor_task_role.role_arn
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
  execution_role_arn                = module.ecs_strapi_execution_role.role_arn
  task_role_arn                     = module.ecs_strapi_task_role.role_arn
  health_check_grace_period_seconds = 300
  cpu                               = "512"
  memory                            = "1024"
  launch_type                       = "FARGATE"
  environment                       = var.environment
  project                           = var.project
  desired_count                     = 1

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]
  target_group_arn       = module.strapi_target_group.target_group_arn
  container_name         = "strapi"
  container_port         = 1337
  namespace_id           = aws_service_discovery_private_dns_namespace.internal.id
  service_discovery_name = "strapi"

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

# ----------- RDS PostgreSQL (Dedicated for Backend Microservices) -----------

module "rds_backend_postgres" {
  source             = "../../../../modules/aws/rds"
  identifier         = "backend-postgres"
  engine             = "postgres"
  engine_version     = var.postgres_engine_version
  instance_class     = "db.m5.xlarge"
  allocated_storage  = 100
  storage_type       = "gp3"
  db_name            = "fixxlybackend"
  username           = var.backend_postgres_master_user_name
  password           = var.backend_postgres_master_user_pass
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
  node_type          = "cache.t3.small"
  subnet_ids         = [module.subnets.private_subnet_ids["db-1"], module.subnets.private_subnet_ids["db-2"]]
  security_group_ids = [module.redis_sg.security_group_id]

  environment = var.environment
  project     = var.project
}

# ----------- Amazon MSK Managed Kafka Cluster -----------

module "msk" {
  source             = "../../../../modules/aws/msk"
  cluster_name       = "${var.environment}-${var.project}-msk"
  kafka_version      = "3.9.x"
  number_of_nodes    = 2
  instance_type      = "kafka.t3.small"
  ebs_volume_size    = 20
  client_subnets     = [module.subnets.private_subnet_ids["app-1"], module.subnets.private_subnet_ids["app-2"]]
  security_group_ids = [module.msk_sg.security_group_id]
  environment        = var.environment
  project            = var.project
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

# =============================================================
# SECTION 5: KAFKA, WEB FRONTEND & BACKEND MICROSERVICES ECS SERVICES
# =============================================================

# --- 1. Web Frontend Service ---
module "ecs_frontend" {
  source                            = "../../../../modules/aws/ecs_service"
  service_name                      = "${var.environment}-${var.project}-frontend"
  family                            = "${var.environment}-${var.project}-frontend-task"
  cluster_arn                       = module.ecs_cluster.cluster_arn
  execution_role_arn                = module.ecs_frontend_execution_role.role_arn
  task_role_arn                     = module.ecs_frontend_task_role.role_arn
  health_check_grace_period_seconds = 300
  cpu                               = "512"
  memory                            = "1024"
  launch_type                       = "FARGATE"
  environment                       = var.environment
  project                           = var.project
  container_name                    = "frontend"
  container_port                    = var.frontend_port
  target_group_arn                  = module.target_group_frontend.target_group_arn

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${module.ecr_frontend.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.frontend_port
          protocol      = "tcp"
        }
      ]
      environment = [for k, v in var.frontend_env_vars : { name = k, value = v }]
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

locals {
  backend_common_secrets = concat(
    [{ name = "DATABASE_URL", valueFrom = "${module.backend_secrets.secret_arn}:DATABASE_URL::" }],
    [for k, v in var.backend_secrets : { name = k, valueFrom = "${module.backend_secrets.secret_arn}:${k}::" }]
  )
  backend_common_env = concat(
    [
      { name = "NODE_ENV", value = "staging" },
      { name = "REDIS_URL", value = "rediss://${module.elasticache_redis.redis_primary_endpoint}:6379" },
      { name = "KAFKA_BROKERS", value = module.msk.bootstrap_brokers_plaintext },
      { name = "AUTH_BASE_URL", value = "http://auth-service.preprod.fixxly.internal:3001" },
      { name = "PRODUCT_BASE_URL", value = "http://product-service.preprod.fixxly.internal:3003" },
      { name = "ORDER_BASE_URL", value = "http://order-service.preprod.fixxly.internal:3004" },
      { name = "CART_BASE_URL", value = "http://cart-service.preprod.fixxly.internal:3005" },
      { name = "INVENTORY_BASE_URL", value = "http://inventory-service.preprod.fixxly.internal:3006" },
      { name = "CMS_BASE_URL", value = "http://cms-bridge.preprod.fixxly.internal:3007" },
      { name = "COUPON_BASE_URL", value = "http://coupon-service.preprod.fixxly.internal:3008" },
      { name = "NOTIFICATION_BASE_URL", value = "http://notification-service.preprod.fixxly.internal:3009" },
      { name = "PAYMENT_BASE_URL", value = "http://payment-service.preprod.fixxly.internal:3010" },
      { name = "ERP_SYNC_BASE_URL", value = "http://erp-sync-service.preprod.fixxly.internal:3011" },
      { name = "WALLET_BASE_URL", value = "http://wallet-service.preprod.fixxly.internal:3012" },
      { name = "ASSETS_BASE_URL", value = "http://assets-service.preprod.fixxly.internal:3013" },
      { name = "SERVICEABILITY_BASE_URL", value = "http://serviceability-service.preprod.fixxly.internal:3014" },
      { name = "REFERRAL_BASE_URL", value = "http://referral-service.preprod.fixxly.internal:3015" }
    ],
    [for k, v in var.backend_env_vars : { name = k, value = v }]
  )

  backend_services = {
    "consumer-bff" = {
      port             = var.consumer_bff_port
      ecr_url          = module.ecr_consumer_bff.repository_url
      target_group_arn = module.target_group_bff.target_group_arn
    }
    "auth-service" = {
      port             = var.auth_service_port
      ecr_url          = module.ecr_auth_service.repository_url
      target_group_arn = null
    }
    "product-service" = {
      port             = var.product_service_port
      ecr_url          = module.ecr_product_service.repository_url
      target_group_arn = module.target_group_product.target_group_arn
    }
    "order-service" = {
      port             = var.order_service_port
      ecr_url          = module.ecr_order_service.repository_url
      target_group_arn = null
    }
    "cart-service" = {
      port             = var.cart_service_port
      ecr_url          = module.ecr_cart_service.repository_url
      target_group_arn = module.target_group_cart.target_group_arn
    }
    "inventory-service" = {
      port             = var.inventory_service_port
      ecr_url          = module.ecr_inventory_service.repository_url
      target_group_arn = module.target_group_inventory.target_group_arn
    }
    "cms-bridge" = {
      port             = var.cms_bridge_port
      ecr_url          = module.ecr_cms_bridge.repository_url
      target_group_arn = null
    }
    "coupon-service" = {
      port             = var.coupon_service_port
      ecr_url          = module.ecr_coupon_service.repository_url
      target_group_arn = module.target_group_coupon.target_group_arn
    }
    "notification-service" = {
      port             = var.notification_service_port
      ecr_url          = module.ecr_notification_service.repository_url
      target_group_arn = null
    }
    "payment-service" = {
      port             = var.payment_service_port
      ecr_url          = module.ecr_payment_service.repository_url
      target_group_arn = module.target_group_payment.target_group_arn
    }
    "erp-sync-service" = {
      port             = var.erp_sync_service_port
      ecr_url          = module.ecr_erp_sync_service.repository_url
      target_group_arn = module.target_group_erp_sync.target_group_arn
    }
    "wallet-service" = {
      port             = var.wallet_service_port
      ecr_url          = module.ecr_wallet_service.repository_url
      target_group_arn = null
    }
    "assets-service" = {
      port             = var.assets_service_port
      ecr_url          = module.ecr_assets_service.repository_url
      target_group_arn = null
    }
    "serviceability-service" = {
      port             = var.serviceability_service_port
      ecr_url          = module.ecr_serviceability_service.repository_url
      target_group_arn = module.target_group_serviceability.target_group_arn
    }
    "referral-service" = {
      port             = var.referral_service_port
      ecr_url          = module.ecr_referral_service.repository_url
      target_group_arn = module.target_group_referral.target_group_arn
    }
  }
}

# --- 3. 14 Backend Microservices ECS Definitions ---
module "ecs_backend_services" {
  for_each                          = local.backend_services
  source                            = "../../../../modules/aws/ecs_service"
  service_name                      = "${var.environment}-${var.project}-${each.key}"
  family                            = "${var.environment}-${var.project}-${each.key}-task"
  cluster_arn                       = module.ecs_cluster.cluster_arn
  execution_role_arn                = module.ecs_backend_execution_role.role_arn
  task_role_arn                     = module.ecs_backend_task_role.role_arn
  health_check_grace_period_seconds = each.value.target_group_arn != null ? 300 : null
  cpu                               = "256"
  memory                            = "512"
  launch_type                       = "FARGATE"
  environment                       = var.environment
  project                           = var.project
  namespace_id                      = aws_service_discovery_private_dns_namespace.internal.id
  service_discovery_name            = each.key
  container_name                    = each.key
  container_port                    = each.value.port
  target_group_arn                  = each.value.target_group_arn

  security_group_ids = [module.app_sg.security_group_id]
  subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
  ]

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${each.value.ecr_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = each.value.port
          protocol      = "tcp"
        }
      ]
      environment = concat(local.backend_common_env, [{ name = "PORT", value = tostring(each.value.port) }])
      secrets     = local.backend_common_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${var.environment}-${var.project}-${each.key}"
        }
      }
    }
  ])
}

# ----------- ECS Application Auto Scaling -----------

# 1. Backend Microservices Auto Scaling
module "ecs_backend_autoscaling" {
  for_each              = local.backend_services
  source                = "../../../../modules/aws/ecs_autoscaling"
  name                  = each.key
  cluster_name          = module.ecs_cluster.cluster_name
  service_name          = module.ecs_backend_services[each.key].service_name
  min_capacity          = 1
  max_capacity          = 3
  enable_cpu_scaling    = true
  cpu_target_value      = 75.0
  enable_memory_scaling = true
  memory_target_value   = 80.0

  environment = var.environment
  project     = var.project
}

# 2. Frontend Auto Scaling (ALB Request Count + CPU)
module "ecs_frontend_autoscaling" {
  source                         = "../../../../modules/aws/ecs_autoscaling"
  name                           = "frontend"
  cluster_name                   = module.ecs_cluster.cluster_name
  service_name                   = module.ecs_frontend.service_name
  min_capacity                   = 1
  max_capacity                   = 4
  enable_cpu_scaling             = true
  cpu_target_value               = 75.0
  alb_arn_suffix                 = module.alb.alb_arn_suffix
  target_group_arn_suffix        = module.target_group_frontend.target_group_arn_suffix
  alb_request_count_target_value = 1000.0

  environment = var.environment
  project     = var.project
}

# 3. Strapi Auto Scaling
module "ecs_strapi_autoscaling" {
  source             = "../../../../modules/aws/ecs_autoscaling"
  name               = "strapi"
  cluster_name       = module.ecs_cluster.cluster_name
  service_name       = module.ecs_strapi.service_name
  min_capacity       = 1
  max_capacity       = 2
  enable_cpu_scaling = true
  cpu_target_value   = 75.0

  environment = var.environment
  project     = var.project
}

# 4. Saleor API Auto Scaling
module "ecs_saleor_api_autoscaling" {
  source             = "../../../../modules/aws/ecs_autoscaling"
  name               = "saleor-api"
  cluster_name       = module.ecs_cluster.cluster_name
  service_name       = module.ecs_saleor_api.service_name
  min_capacity       = 2
  max_capacity       = 5
  enable_cpu_scaling = true
  cpu_target_value   = 75.0

  environment = var.environment
  project     = var.project
}

# 5. Saleor Worker Auto Scaling
module "ecs_saleor_worker_autoscaling" {
  source             = "../../../../modules/aws/ecs_autoscaling"
  name               = "saleor-worker"
  cluster_name       = module.ecs_cluster.cluster_name
  service_name       = module.ecs_saleor_worker.service_name
  min_capacity       = 1
  max_capacity       = 3
  enable_cpu_scaling = true
  cpu_target_value   = 75.0

  environment = var.environment
  project     = var.project
}

