terraform {
    required_version = ">= 1.5.0"
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
    backend "s3" {
        bucket       = "sammmm-terraform-state-847659"
        key          = "sam/staging/terraform.tfstate"
        region       = "ap-south-1"
        profile      = "sam"
        use_lockfile = true
        encrypt      = true
    }
}

provider "aws" {
    region = var.aws_region
    profile = var.aws_profile 
}

module "vpc" {
    source = "../../../../modules/vpc"
    vpc_cidr = var.vpc_cidr
    instance_tenancy = var.instance_tenancy
    enable_dns_hostnames = var.enable_dns_hostnames
    enable_dns_support = var.enable_dns_support
    environment = var.environment
    project = var.project
}

module "subnets" {
    source = "../../../../modules/subnets"
    vpc_id = module.vpc.vpc_id
    public_subnets = var.public_subnets
    private_subnets = var.private_subnets
    environment = var.environment
    project = var.project
}

module "igw" {
    source = "../../../../modules/igw"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project
}

module "eip" {
    source = "../../../../modules/eip"
    environment = var.environment
    project = var.project
}

module "nat_gateway" {
    source = "../../../../modules/nat_gateway"
    eip_allocation_id = module.eip.eip_allocation_id
    public_subnet_id = module.subnets.public_subnet_ids["public-1"]
    igw_dependency = module.igw.igw_id
    environment = var.environment
    project = var.project
}

module "route_tables" {
    source = "../../../../modules/route_tables"
    vpc_id = module.vpc.vpc_id
    igw_id = module.igw.igw_id
    nat_gateway_id = module.nat_gateway.nat_gateway_id
    environment = var.environment
    project = var.project
}

module "route_table_association" {
    source = "../../../../modules/route_table_association"
    public_subnet_ids = module.subnets.public_subnet_ids
    private_subnet_ids = module.subnets.private_subnet_ids
    public_route_table_id = module.route_tables.public_route_table_id
    private_route_table_id = module.route_tables.private_route_table_id
}



// --------- Security Groups ------------------
module "alb_sg" {
    source = "../../../../modules/security_groups"
    name = "abl"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project

    ingress_rules = [
        {
            from_port = 80
            to_port = 80
            protocol = "tcp"
            description = "Allow HTTP traffic"

            cidr_blocks = ["0.0.0.0/0"]
        },
        {
            from_port = 443
            to_port = 443
            protocol = "tcp"
            description = "Allow HTTPS traffic"
            cidr_blocks = ["0.0.0.0/0"]
        }
    ]

    egress_rules = [
        {
            from_port = 0
            to_port = 0
            protocol = "-1"
            description = ""
            cidr_blocks = ["0.0.0.0/0"]
        }
    ]
}

module "app_sg" {
    source = "../../../../modules/security_groups"

    name = "wordpress"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project

    ingress_rules = [
        {
            from_port = 8000
            to_port = 8000
            protocol = "tcp"
            description = "Allow traffic from ALB"

            cidr_blocks = []
            security_groups = [
                module.alb_sg.security_group_id
            ]
        }
    ]



    egress_rules = [
        {
            from_port = 0
            to_port = 0
            protocol = "-1"
            description = ""
            cidr_blocks = ["0.0.0.0/0"]
            security_groups = []
        }
    ]
}

module "redis-sg" {
    source = "../../../../modules/security_groups"
    name = "redis"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project

    ingress_rules = [
        {
            from_port = 6379
            to_port = 6379
            protocol = "tcp"
            description = "Allow traffic from Application"

            cidr_blocks = []
            security_groups = [
                module.app_sg.security_group_id
            ]
        }
    ]

    egress_rules = [
        {
            from_port = 0
            to_port = 0
            protocol = "-1"
            description = ""
            cidr_blocks = ["0.0.0.0/0"]
            security_groups = []
        }
    ]
}

module "db-sg" {
    source = "../../../../modules/security_groups"

    name = "aurora"
    vpc_id = module.vpc.vpc_id
    environment = var.environment
    project = var.project

    ingress_rules = [
        {
            from_port = 3306
            to_port = 3306
            protocol = "tcp"
            description = "Allow traffic from Application"

            cidr_blocks = []
            security_groups = [
                module.app_sg.security_group_id
            ]
        }
    ]

    egress_rules = [
        {
            from_port = 0
            to_port = 0
            protocol = "-1"
            description = ""
            cidr_blocks = ["0.0.0.0/0"]
            security_groups = []
        }
    ]
}
//-----------------------------------

// SQS_DQL and SQS Queue

module "sqs_dlq" {
    source = "../../../../modules/sqs"
    name = "app-dlq"
    environment = var.environment
    project = var.project
}


module "sqs" {
    source = "../../../../modules/sqs"
    name = "app-queue"
    environment = var.environment
    project = var.project

    dlq_arn = module.sqs_dlq.queue_arn
}
//--------------------------------------


// Aurora Serverless v2 ----------

module "aurora" {
    source = "../../../../modules/aurora"
    cluster_identifier = "aurora-db"
    
    # Enable Serverless v2
    instance_class = "db.serverless"
    num_instances = 1

    engine = "aurora-mysql"
    engine_version = "8.0.mysql_aurora.3.10.1"
    database_name = "stg_app_db"
    master_username = var.master_db_user_name
    master_password = var.master_db_user_pass

    subnet_ids = [
        module.subnets.private_subnet_ids["db-1"],
        module.subnets.private_subnet_ids["db-2"]
    ]
    
    security_group_ids = [
        module.db-sg.security_group_id
    ]

    environment = var.environment
    project = var.project
}
//----------------------------------

// --------- Redis ----------
module "redis" {
    source = "../../../../modules/elasticache"
    name = "cache"
    engine = "redis"
    node_type = "cache.t3.micro"
    num_cache_clusters = 1
    transit_encryption = false
    at_rest_encryption = false

    subnet_ids = [
        module.subnets.private_subnet_ids["db-1"],
        module.subnets.private_subnet_ids["db-2"]
    ]

    security_group_ids = [
        module.redis-sg.security_group_id
    ]

    environment = var.environment
    project = var.project
}



//----------------------------
// Load Balancing Tier
# 1. Target Group (Routing destination for Fargate containers)

module "target_group" {
    source = "../../../../modules/target_group"
    name = "app-tg"
    port = 8000
    protocol = "HTTP"
    target_type = "ip"
    vpc_id = module.vpc.vpc_id
    health_check_path = var.health_check_path
    environment = var.environment
    project = var.project
}

# 2 Application Load Balancer (Receives web traffic)

module "alb" {
    source = "../../../../modules/alb"
    name = "app-alb"
    internal = false
    security_group_ids = [
        module.alb_sg.security_group_id
    ]

    subnet_ids = [
        module.subnets.public_subnet_ids["public-1"],
        module.subnets.public_subnet_ids["public-2"]
    ]

    http_default_action = "forward"
    http_target_group_arn = module.target_group.target_group_arn
    environment = var.environment
    project = var.project
}
//--------------------------

// Container Runtime Tier
# ECS Fargate Cluster & Service

module "ecs_fargate" {
    source = "../../../../modules/ecs_fargate"
    cluster_name = "app-sammmm"
    service_name = "sammmm-backend"
    task_family = "sammmm-backend-task"

    cpu = 256
    memory = 512
    desired_count = 1

    subnet_ids = [
    module.subnets.private_subnet_ids["app-1"],
    module.subnets.private_subnet_ids["app-2"]
   ]

   security_group_ids = [
    module.app_sg.security_group_id
   ]

    # Bind to to ALB
    target_group_arn = module.target_group.target_group_arn
    container_name = "sammmm-backend"
    container_port = 8000

    # Container Specifications
    container_definitions = jsonencode ([
        {
            name = "sammmm-backend"
            image = "python:3.11-slim"

            essential = true
            portMappings = [
                {
                    containerPort = 8000
                    hostPort = 8000
                    protocol = "tcp"
                }
            ]

            environment = [
                {name = "ENVIRONMENT", value = var.environment},
                {name = "SQS_QUEUE_URL", value = module.sqs.queue_url},
                {name = "DB_HOST", value = module.aurora.cluster_endpoint},
                {name = "REDIS_HOST", value = module.redis.redis_primary_endpoint}
            ]

            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    "awslogs-group" = "/ecs/staging-sammmm-backend"
                    "awslogs-region" = var.aws_region
                    "awslogs-stream-prefix" = "ecs"
                    "awslogs-create-group" = "true"
                }
            }
        }
    ])
    environment = var.environment
    project = var.project
}

module "ecr" {
    source = "../../../../modules/ecr"
    name = "sammmm-backend"
    environment = var.environment
    project = var.project
    image_tag_mutability = "IMMUTABLE"
    scan_on_push = false

}