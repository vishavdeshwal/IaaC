terraform {
    required_version = ">= 1.5.0"
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
    backend "s3" {
        bucket       = "altrx-terraform-state-993197"
        key          = "altrx/prod/terraform.tfstate"
        region       = "us-east-1"
        profile      = "altrx"
        use_lockfile = true
        encrypt      = true
    }
}

provider "aws" {
    region  = var.aws_region
    profile = var.aws_profile 
}



module "vpc" {
    source               = "../../../../modules/vpc"
    vpc_cidr             = var.vpc_cidr
    instance_tenancy     = var.instance_tenancy
    enable_dns_hostnames = var.enable_dns_hostnames
    enable_dns_support   = var.enable_dns_support
    environment          = var.environment
    project              = var.project
}

module "subnets" {
    source          = "../../../../modules/subnets"
    vpc_id          = module.vpc.vpc_id
    public_subnets  = var.public_subnets
    private_subnets = var.private_subnets
    environment     = var.environment
    project         = var.project
}

module "igw" {
    source      = "../../../../modules/igw"
    vpc_id      = module.vpc.vpc_id
    environment = var.environment
    project     = var.project
}


resource "aws_security_group" "prod_redis" {
  description = "Allows Redis traffic"
  egress = [{
    cidr_blocks      = []
    description      = ""
    from_port        = 6379
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = ["sg-023679ff04932ed99"]
    self             = false
    to_port          = 6379
  }]
  ingress = [{
    cidr_blocks      = []
    description      = ""
    from_port        = 6379
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = ["sg-023679ff04932ed99"]
    self             = false
    to_port          = 6379
  }]
  name                   = "Prod-Redis-Sg"
  revoke_rules_on_delete = null
  tags                   = {}
  tags_all               = {}
  vpc_id                 = module.vpc.vpc_id
}

resource "aws_security_group" "prod_alb" {
  description = "It allows internet traffic"
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 443
    }, {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 80
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 80
  }]
  name                   = "Prod-ALB-SG"
  revoke_rules_on_delete = null
  tags                   = {}
  tags_all               = {}
  vpc_id                 = module.vpc.vpc_id
}

resource "aws_security_group" "default" {
  description = "default VPC security group"
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress = [{
    cidr_blocks      = []
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = true
    to_port          = 0
  }]
  name                   = "default"
  revoke_rules_on_delete = null
  tags                   = {}
  tags_all               = {}
  vpc_id                 = module.vpc.vpc_id
}

resource "aws_security_group" "prod_be" {
  description = "Allow ALB Traffic"
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress = [{
    cidr_blocks      = []
    description      = ""
    from_port        = 8000
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = ["sg-09fab770ac39d96eb"]
    self             = false
    to_port          = 8000
  }]
  name                   = "Prod-BE-SG"
  revoke_rules_on_delete = null
  tags                   = {}
  tags_all               = {}
  vpc_id                 = module.vpc.vpc_id
}

resource "aws_security_group" "worker" {
  description = "Allow Outbound and Inbound specific"
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress                = []
  name                   = "Worker-SG"
  revoke_rules_on_delete = null
  tags                   = {}
  tags_all               = {}
  vpc_id                 = module.vpc.vpc_id
}

resource "aws_security_group" "wordpress" {
  description = "launch-wizard-1 created 2026-04-20T18:09:51.774Z"
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 22
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 22
    }, {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 443
    }, {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 80
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 80
  }]
  name                   = "wordpress-sg"
  revoke_rules_on_delete = null
  tags                   = {}
  tags_all               = {}
  vpc_id                 = module.vpc.vpc_id
}


# =============================================================
# Consolidated Databases (DynamoDB & Redis)
# =============================================================
# __generated__ by Terraform from "prod-sg"
resource "aws_elasticache_subnet_group" "prod_redis" {
  description = " "
  name        = "prod-sg"
  subnet_ids  = ["subnet-014c46a812d1d03fe", "subnet-0a27b74e8073476d3"]
  tags        = {}
  tags_all    = {}
}

# __generated__ by Terraform
resource "aws_dynamodb_table" "payment_events_log" {
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = false
  hash_key                    = "event_id"
  name                        = "production_altrx-payment-events-log"
  range_key                   = "received_at"
  read_capacity               = 0
  restore_date_time           = null
  restore_source_name         = null
  restore_source_table_arn    = null
  restore_to_latest_time      = null
  stream_enabled              = false
  table_class                 = "STANDARD"
  tags                        = {}
  tags_all                    = {}
  write_capacity              = 0
  attribute {
    name = "event_id"
    type = "S"
  }
  attribute {
    name = "received_at"
    type = "S"
  }
  ttl {
    attribute_name = null
    enabled        = false
  }
}

# __generated__ by Terraform
resource "aws_elasticache_replication_group" "prod_redis" {
  at_rest_encryption_enabled  = "true"
  auth_token                  = null # sensitive
  auth_token_update_strategy  = null
  auto_minor_version_upgrade  = "true"
  automatic_failover_enabled  = false
  cluster_mode                = "disabled"
  data_tiering_enabled        = false
  description                 = " "
  engine                      = "redis"
  engine_version              = "7.1"
  final_snapshot_identifier   = null
  ip_discovery                = "ipv4"
  kms_key_id                  = null
  maintenance_window          = "thu:04:00-thu:05:00"
  multi_az_enabled            = false
  network_type                = "ipv4"
  node_type                   = "cache.t3.small"
  notification_topic_arn      = null
  num_cache_clusters          = 2
  parameter_group_name        = "default.redis7"
  port                        = 6379
  preferred_cache_cluster_azs = null
  replication_group_id        = "prod-redis"
  security_group_ids          = ["sg-0cd3a8911f4af223b"]
  security_group_names        = []
  snapshot_arns               = null
  snapshot_name               = null
  snapshot_retention_limit    = 1
  snapshot_window             = "06:30-07:30"
  subnet_group_name           = "prod-sg"
  tags                        = {}
  tags_all                    = {}
  transit_encryption_enabled  = true
  transit_encryption_mode     = "required"
  user_group_ids              = []
  log_delivery_configuration {
    destination      = "redis-prod"
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }
}

# __generated__ by Terraform
resource "aws_dynamodb_table" "processed_events" {
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = false
  hash_key                    = "event_id"
  name                        = "production_altrx-processed-events"
  range_key                   = null
  read_capacity               = 0
  restore_date_time           = null
  restore_source_name         = null
  restore_source_table_arn    = null
  restore_to_latest_time      = null
  stream_enabled              = false
  table_class                 = "STANDARD"
  tags                        = {}
  tags_all                    = {}
  write_capacity              = 0
  attribute {
    name = "event_id"
    type = "S"
  }
  ttl {
    attribute_name = null
    enabled        = false
  }
}

# __generated__ by Terraform
resource "aws_dynamodb_table" "stripe_customers" {
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = false
  hash_key                    = "stripe_customer_id"
  name                        = "production_altrx-stripe-customers"
  range_key                   = null
  read_capacity               = 0
  restore_date_time           = null
  restore_source_name         = null
  restore_source_table_arn    = null
  restore_to_latest_time      = null
  stream_enabled              = false
  table_class                 = "STANDARD"
  tags                        = {}
  tags_all                    = {}
  write_capacity              = 0
  attribute {
    name = "account"
    type = "S"
  }
  attribute {
    name = "email"
    type = "S"
  }
  attribute {
    name = "stripe_customer_id"
    type = "S"
  }
  global_secondary_index {
    hash_key           = "email"
    name               = "email-account-index"
    non_key_attributes = []
    projection_type    = "ALL"
    range_key          = "account"
    read_capacity      = 0
    write_capacity     = 0
  }
  ttl {
    attribute_name = null
    enabled        = false
  }
}

# __generated__ by Terraform
resource "aws_dynamodb_table" "checkout_submissions" {
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true
  hash_key                    = "submission_token"
  name                        = "production_altrx-checkout-submissions"
  range_key                   = null
  read_capacity               = 0
  restore_date_time           = null
  restore_source_name         = null
  restore_source_table_arn    = null
  restore_to_latest_time      = null
  stream_enabled              = false
  table_class                 = "STANDARD"
  tags                        = {}
  tags_all                    = {}
  write_capacity              = 0
  attribute {
    name = "provider_id"
    type = "S"
  }
  attribute {
    name = "submission_token"
    type = "S"
  }
  global_secondary_index {
    hash_key           = "provider_id"
    name               = "provider_id-index"
    non_key_attributes = []
    projection_type    = "ALL"
    range_key          = null
    read_capacity      = 0
    write_capacity     = 0
  }
  ttl {
    attribute_name = null
    enabled        = false
  }
}


# =============================================================
# Consolidated Load Balancing (ALB, Listeners, Target Groups)
# =============================================================
# __generated__ by Terraform
resource "aws_lb_listener" "prod_http" {
  alpn_policy                          = null
  certificate_arn                      = null
  load_balancer_arn                    = "arn:aws:elasticloadbalancing:us-east-1:692137657276:loadbalancer/app/Prod-ALB/ee60104edbc08457"
  port                                 = 80
  protocol                             = "HTTP"
  routing_http_response_server_enabled = true
  tags                                 = {}
  tags_all                             = {}
  default_action {
    target_group_arn = null
    type             = "redirect"
    redirect {
      host        = "#{host}"
      path        = "/#{path}"
      port        = "443"
      protocol    = "HTTPS"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }
}

# __generated__ by Terraform from "arn:aws:elasticloadbalancing:us-east-1:692137657276:listener/app/Prod-ALB/ee60104edbc08457/800a4e4492f73cf6"
resource "aws_lb_listener" "prod_https" {
  alpn_policy                          = null
  certificate_arn                      = "arn:aws:acm:us-east-1:692137657276:certificate/33647a6f-f1c6-4ae8-aa6e-a58602892404"
  load_balancer_arn                    = "arn:aws:elasticloadbalancing:us-east-1:692137657276:loadbalancer/app/Prod-ALB/ee60104edbc08457"
  port                                 = 443
  protocol                             = "HTTPS"
  routing_http_response_server_enabled = true
  ssl_policy                           = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  tags                                 = {}
  tags_all                             = {}
  default_action {
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:692137657276:targetgroup/Prod-Backend/9047f93ec179e5be"
    type             = "forward"
    forward {
      stickiness {
        duration = 3600
        enabled  = false
      }
      target_group {
        arn    = "arn:aws:elasticloadbalancing:us-east-1:692137657276:targetgroup/Prod-Backend/9047f93ec179e5be"
        weight = 1
      }
    }
  }
  mutual_authentication {
    ignore_client_certificate_expiry = false
    mode                             = "off"
    trust_store_arn                  = null
  }
}

# __generated__ by Terraform
resource "aws_lb_target_group" "prod_backend" {
  deregistration_delay               = "300"
  ip_address_type                    = "ipv4"
  lambda_multi_value_headers_enabled = null
  load_balancing_algorithm_type      = "round_robin"
  load_balancing_anomaly_mitigation  = "off"
  load_balancing_cross_zone_enabled  = "use_load_balancer_configuration"
  name                               = "Prod-Backend"
  port                               = 8000
  protocol                           = "HTTP"
  protocol_version                   = "HTTP1"
  proxy_protocol_v2                  = null
  slow_start                         = 0
  tags                               = {}
  tags_all                           = {}
  target_type                        = "ip"
  vpc_id                             = "vpc-06c0d2be8ccc003e3"
  health_check {
    enabled             = true
    healthy_threshold   = 5
    interval            = 30
    matcher             = "200"
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  stickiness {
    cookie_duration = 86400
    cookie_name     = null
    enabled         = false
    type            = "lb_cookie"
  }
  target_group_health {
    dns_failover {
      minimum_healthy_targets_count      = "1"
      minimum_healthy_targets_percentage = "off"
    }
    unhealthy_state_routing {
      minimum_healthy_targets_count      = 1
      minimum_healthy_targets_percentage = "off"
    }
  }
}

# __generated__ by Terraform
resource "aws_lb" "prod_alb" {
  client_keep_alive                           = 3600
  customer_owned_ipv4_pool                    = null
  desync_mitigation_mode                      = "defensive"
  dns_record_client_routing_policy            = null
  drop_invalid_header_fields                  = false
  enable_cross_zone_load_balancing            = true
  enable_deletion_protection                  = false
  enable_http2                                = true
  enable_tls_version_and_cipher_suite_headers = false
  enable_waf_fail_open                        = false
  enable_xff_client_port                      = false
  enable_zonal_shift                          = false
  idle_timeout                                = 60
  internal                                    = false
  ip_address_type                             = "ipv4"
  load_balancer_type                          = "application"
  name                                        = "Prod-ALB"
  preserve_host_header                        = false
  security_groups                             = ["sg-09fab770ac39d96eb"]
  subnets                                     = ["subnet-014c46a812d1d03fe", "subnet-02e5dbd52bb57f9d3"]
  tags                                        = {}
  tags_all                                    = {}
  xff_header_processing_mode                  = "append"
  access_logs {
    bucket  = ""
    enabled = false
    prefix  = null
  }
  connection_logs {
    bucket  = ""
    enabled = false
    prefix  = null
  }
}


# =============================================================
# Consolidated SQS Queues
# =============================================================
# __generated__ by Terraform
resource "aws_sqs_queue" "production_altrx_payment_events_dlq" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  kms_master_key_id                 = null
  max_message_size = 262144
  message_retention_seconds         = 1209600
  name                              = "production_altrx-payment-events-dlq"
  receive_wait_time_seconds         = 0
  sqs_managed_sse_enabled           = true
  tags                              = {}
  tags_all                          = {}
  visibility_timeout_seconds        = 30
}

# __generated__ by Terraform
resource "aws_sqs_queue" "production_altrx_payment_events" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  kms_master_key_id                 = null
  max_message_size = 262144
  message_retention_seconds         = 345600
  name                              = "production_altrx-payment-events"
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:production_altrx-payment-events"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
  receive_wait_time_seconds = 0
  redrive_policy = jsonencode({
    deadLetterTargetArn = "arn:aws:sqs:us-east-1:692137657276:production_altrx-payment-events-dlq"
    maxReceiveCount     = 5
  })
  sqs_managed_sse_enabled    = true
  tags                       = {}
  tags_all                   = {}
  visibility_timeout_seconds = 30
}

# __generated__ by Terraform from "https://sqs.us-east-1.amazonaws.com/692137657276/altrx-reconciler-trigger-dlq"
resource "aws_sqs_queue" "altrx_reconciler_trigger_dlq" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  kms_master_key_id                 = null
  max_message_size                  = 262144
  message_retention_seconds         = 1209600
  name                              = "altrx-reconciler-trigger-dlq"
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger-dlq"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
  receive_wait_time_seconds  = 0
  sqs_managed_sse_enabled    = true
  tags                       = {}
  tags_all                   = {}
  visibility_timeout_seconds = 30
}

# __generated__ by Terraform
resource "aws_sqs_queue" "altrx_reconciler_trigger" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  kms_master_key_id                 = null
  max_message_size = 262144
  message_retention_seconds         = 345600
  name                              = "altrx-reconciler-trigger"
  policy = jsonencode({
    Id = "__default_policy_ID"
    Statement = [{
      Action = "SQS:*"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::692137657276:root"
      }
      Resource = "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger"
      Sid      = "__owner_statement"
    }]
    Version = "2012-10-17"
  })
  receive_wait_time_seconds = 0
  redrive_policy = jsonencode({
    deadLetterTargetArn = "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger-dlq"
    maxReceiveCount     = 5
  })
  sqs_managed_sse_enabled    = true
  tags                       = {}
  tags_all                   = {}
  visibility_timeout_seconds = 660
}


# =============================================================
# Consolidated CloudWatch Logging Groups
# =============================================================
# __generated__ by Terraform from "/ecs/prod-worker"
resource "aws_cloudwatch_log_group" "prod_worker" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/ecs/prod-worker"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

# __generated__ by Terraform from "/aws/lambda/altrx-reconciler"
resource "aws_cloudwatch_log_group" "reconciler" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/aws/lambda/altrx-reconciler"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

# __generated__ by Terraform from "/aws/amplify/dsx3g35brvnhn"
resource "aws_cloudwatch_log_group" "amplify" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/aws/amplify/dsx3g35brvnhn"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

# __generated__ by Terraform from "redis-prod"
resource "aws_cloudwatch_log_group" "redis_prod" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "redis-prod"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

# __generated__ by Terraform from "/ecs/prod-backend"
resource "aws_cloudwatch_log_group" "prod_backend" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/ecs/prod-backend"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

# __generated__ by Terraform from "/aws/ecs/containerinsights/Prod-Altrx/performance"
resource "aws_cloudwatch_log_group" "ecs_performance" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/aws/ecs/containerinsights/Prod-Altrx/performance"
  retention_in_days = 1
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}

# __generated__ by Terraform from "/ecs/Prod-Worker-Payment"
resource "aws_cloudwatch_log_group" "prod_worker_payment" {
  kms_key_id        = null
  log_group_class   = "STANDARD"
  name              = "/ecs/Prod-Worker-Payment"
  retention_in_days = 0
  skip_destroy      = false
  tags              = {}
  tags_all          = {}
}


# =============================================================
# Consolidated IAM Roles & Policies
# =============================================================
# __generated__ by Terraform from "arn:aws:iam::692137657276:policy/custom_user_vishal_AI"
resource "aws_iam_policy" "custom_user_vishal_ai_policy" {
  description = null
  name        = "custom_user_vishal_AI"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = ["cloudshell:*", "dynamodb:*", "sqs:*", "sts:GetCallerIdentity", "ec2:Describe*", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroup*", "ec2:RevokeSecurityGroup*", "ec2:CreateTags", "ecs:*", "application-autoscaling:*", "cloudwatch:*", "logs:DescribeLogGroups", "logs:DescribeLogStreams", "iam:ListRoles", "iam:GetUser", "iam:GetPolicy", "iam:GetPolicyVersion", "ecr:GetAuthorizationToken", "secretsmanager:ListSecrets", "amplify:ListApps", "amplify:GetApp"]
      Effect   = "Allow"
      Resource = "*"
      Sid      = "BaseAndAmplify"
      }, {
      Action   = "amplify:*"
      Effect   = "Allow"
      Resource = ["arn:aws:amplify:*:692137657276:apps/d1afdsckfq42or", "arn:aws:amplify:*:692137657276:apps/d1afdsckfq42or/*", "arn:aws:amplify:*:692137657276:apps/d9m305ipl0ufl", "arn:aws:amplify:*:692137657276:apps/d9m305ipl0ufl/*", "arn:aws:amplify:*:692137657276:apps/d1onpspxsudhmw", "arn:aws:amplify:*:692137657276:apps/d1onpspxsudhmw/*"]
      Sid      = "AmplifyApps"
      }, {
      Action   = "logs:*"
      Effect   = "Allow"
      Resource = ["arn:aws:logs:*:692137657276:log-group:/aws/amplify/*", "arn:aws:logs:*:692137657276:log-group:/aws/amplify/*:*", "arn:aws:logs:*:692137657276:log-group:/aws/ecs/*altrx*", "arn:aws:logs:*:692137657276:log-group:/aws/ecs/*altrx*:*", "arn:aws:logs:*:692137657276:log-group:*altrx*", "arn:aws:logs:*:692137657276:log-group:*altrx*:*"]
      Sid      = "AmplifyAndAltrxLogs"
      }, {
      Action   = "ecr:*"
      Effect   = "Allow"
      Resource = ["arn:aws:ecr:*:692137657276:repository/altrx-*", "arn:aws:ecr:*:692137657276:repository/staging_altrx-*", "arn:aws:ecr:*:692137657276:repository/preprod_altrx-*"]
      Sid      = "ECR"
      }, {
      Action   = ["secretsmanager:CreateSecret", "secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:UpdateSecret", "secretsmanager:PutSecretValue", "secretsmanager:DeleteSecret", "secretsmanager:RestoreSecret", "secretsmanager:TagResource", "secretsmanager:UntagResource", "secretsmanager:ListSecretVersionIds", "secretsmanager:GetResourcePolicy"]
      Effect   = "Allow"
      Resource = ["arn:aws:secretsmanager:*:692137657276:secret:altrx/*", "arn:aws:secretsmanager:*:692137657276:secret:staging_altrx/*", "arn:aws:secretsmanager:*:692137657276:secret:preprod_altrx/*"]
      Sid      = "SecretsManagerAltrx"
      }, {
      Action   = ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies", "iam:TagRole", "iam:UntagRole"]
      Effect   = "Allow"
      Resource = ["arn:aws:iam::692137657276:role/altrx-*", "arn:aws:iam::692137657276:role/staging_altrx-*", "arn:aws:iam::692137657276:role/preprod_altrx-*"]
      Sid      = "IAMManageAltrxRoles"
      }, {
      Action = "iam:PassRole"
      Condition = {
        StringEquals = {
          "iam:PassedToService" = ["ecs-tasks.amazonaws.com", "amplify.amazonaws.com", "application-autoscaling.amazonaws.com"]
        }
      }
      Effect   = "Allow"
      Resource = ["arn:aws:iam::692137657276:role/altrx-*", "arn:aws:iam::692137657276:role/staging_altrx-*", "arn:aws:iam::692137657276:role/preprod_altrx-*", "arn:aws:iam::692137657276:role/service-role/AmplifySSRLoggingRole-*"]
      Sid      = "PassRoleScoped"
      }, {
      Action = "iam:CreateServiceLinkedRole"
      Condition = {
        StringEquals = {
          "iam:AWSServiceName" = ["ecs.amazonaws.com", "application-autoscaling.amazonaws.com", "ecs.application-autoscaling.amazonaws.com"]
        }
      }
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ServiceLinkedRoles"
      }, {
      Action   = "ecr:GetAuthorizationToken"
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ECRAuth"
      }, {
      Action   = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"]
      Effect   = "Allow"
      Resource = ["arn:aws:ecr:us-east-1:692137657276:repository/prod-backend", "arn:aws:ecr:us-east-1:692137657276:repository/preprod-backend"]
      Sid      = "ECRPush"
      }, {
      Action   = ["ecs:UpdateService", "ecs:DescribeServices", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ECSDeploy"
      }, {
      Action = "iam:PassRole"
      Condition = {
        StringLike = {
          "iam:PassedToService" = "ecs-tasks.amazonaws.com"
        }
      }
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ECSPassRole"
    }]
    Version = "2012-10-17"
  })
  tags     = {}
  tags_all = {}
}

# __generated__ by Terraform from "arn:aws:iam::692137657276:policy/service-role/AmplifySSRLoggingPolicy-638507c3-6940-4947-b58d-16f5ca25c35a"
resource "aws_iam_policy" "amplify_ssr_logging_policy" {
  description = null
  name        = "AmplifySSRLoggingPolicy-638507c3-6940-4947-b58d-16f5ca25c35a"
  path        = "/service-role/"
  policy = jsonencode({
    Statement = [{
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Effect   = "Allow"
      Resource = "arn:aws:logs:us-east-1:692137657276:log-group:/aws/amplify/*:log-stream:*"
      Sid      = "PushLogs"
      }, {
      Action   = "logs:CreateLogGroup"
      Effect   = "Allow"
      Resource = "arn:aws:logs:us-east-1:692137657276:log-group:/aws/amplify/*"
      Sid      = "CreateLogGroup"
      }, {
      Action   = "logs:DescribeLogGroups"
      Effect   = "Allow"
      Resource = "arn:aws:logs:us-east-1:692137657276:log-group:*"
      Sid      = "DescribeLogGroups"
    }]
    Version = "2012-10-17"
  })
  tags     = {}
  tags_all = {}
}

# __generated__ by Terraform from "ECS-Task-execution-role"
resource "aws_iam_role" "ecs_task_execution_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ecs:us-east-1:692137657276:*"
        }
        StringEquals = {
          "aws:SourceAccount" = "692137657276"
        }
      }
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  description           = null
  force_detach_policies = false
  max_session_duration  = 3600
  name                  = "ECS-Task-execution-role"
  path                  = "/"
  permissions_boundary  = null
  tags                  = {}
  tags_all              = {}
}

# __generated__ by Terraform from "altrx_ssm_role"
resource "aws_iam_role" "altrx_ssm_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  description           = "Allows EC2 instances to call AWS services on your behalf."
  force_detach_policies = false
  max_session_duration  = 3600
  name                  = "altrx_ssm_role"
  path                  = "/"
  permissions_boundary  = null
  tags                  = {}
  tags_all              = {}
}

# __generated__ by Terraform from "arn:aws:iam::692137657276:policy/Custom_S3_Vishal_ai"
resource "aws_iam_policy" "custom_s3_vishal_ai_policy" {
  description = null
  name        = "Custom_S3_Vishal_ai"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = ["s3:PutBucketCORS", "s3:GetBucketCORS"]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::production-altrx-v3-uploads"
      }, {
      Action   = ["s3:PutObject", "s3:PutObjectAcl"]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::production-altrx-v3-uploads/worker-env/worker.env"
      Sid      = "WriteWorkerEnv"
      }, {
      Action   = ["ecs:UpdateService"]
      Effect   = "Allow"
      Resource = "arn:aws:ecs:us-east-1:692137657276:service/Prod-Altrx/Prod-Worker"
      Sid      = "RestartWorker"
      }, {
      Action   = ["sqs:StartMessageMoveTask", "sqs:ListMessageMoveTasks"]
      Effect   = "Allow"
      Resource = ["arn:aws:sqs:us-east-1:692137657276:production_altrx-payment-events", "arn:aws:sqs:us-east-1:692137657276:production_altrx-payment-events-dlq"]
      Sid      = "DrainDLQ"
      }, {
      Action   = ["s3:CreateBucket", "s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock", "s3:PutEncryptionConfiguration", "s3:GetEncryptionConfiguration", "s3:PutBucketCORS", "s3:GetBucketCORS", "s3:PutLifecycleConfiguration", "s3:GetLifecycleConfiguration", "s3:PutBucketTagging", "s3:GetBucketTagging", "s3:GetBucketLocation", "s3:ListBucket"]
      Effect   = "Allow"
      Resource = ["arn:aws:s3:::staging-altrx-v3-uploads", "arn:aws:s3:::preprod-altrx-v3-uploads"]
      Sid      = "ProvisionAltrxV3UploadBuckets"
      }, {
      Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
      Effect   = "Allow"
      Resource = ["arn:aws:s3:::staging-altrx-v3-uploads/v3/pen-uploads/*", "arn:aws:s3:::preprod-altrx-v3-uploads/v3/pen-uploads/*"]
      Sid      = "SmokeTestObjectsInAltrxV3UploadBuckets"
      }, {
      Action = "lambda:ListFunctions"
      Condition = {
        StringEquals = {
          "aws:RequestedRegion" = "us-east-1"
        }
      }
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ListLambdaInUsEast1Only"
      }, {
      Action   = "lambda:GetFunctionConfiguration"
      Effect   = "Allow"
      Resource = ["arn:aws:lambda:us-east-1:692137657276:function:amplify-d9m305ipl0ufl-*", "arn:aws:lambda:us-east-1:692137657276:function:amplify-d1onpspxsudhmw-*"]
      Sid      = "ReadAmplifySSRFunctionConfig"
    }]
    Version = "2012-10-17"
  })
  tags     = {}
  tags_all = {}
}

# __generated__ by Terraform from "AmplifySSRLoggingRole-638507c3-6940-4947-b58d-16f5ca25c35a"
resource "aws_iam_role" "amplify_ssr_logging_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "amplify.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  description           = "The service role that will be used by AWS Amplify for Web Compute app logging."
  force_detach_policies = false
  max_session_duration  = 3600
  name                  = "AmplifySSRLoggingRole-638507c3-6940-4947-b58d-16f5ca25c35a"
  path                  = "/service-role/"
  permissions_boundary  = null
  tags                  = {}
  tags_all              = {}
}

# __generated__ by Terraform from "arn:aws:iam::692137657276:policy/AltrxReconcilerPolicy"
resource "aws_iam_policy" "altrx_reconciler_policy" {
  description = null
  name        = "AltrxReconcilerPolicy"
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:DescribeTable"]
      Effect   = "Allow"
      Resource = ["arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-checkout-submissions", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-checkout-submissions/index/*", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-stripe-customers", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-stripe-customers/index/*", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-processed-events", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-events-log", "arn:aws:dynamodb:us-east-1:692137657276:table/production_altrx-events-log/index/*"]
      Sid      = "DynamoDBAccess"
      }, {
      Action   = ["sqs:SendMessage"]
      Effect   = "Allow"
      Resource = "arn:aws:sqs:us-east-1:692137657276:altrx-reconciler-trigger"
      Sid      = "SQSSelfChain"
      }, {
      Action   = ["secretsmanager:GetSecretValue"]
      Effect   = "Allow"
      Resource = "arn:aws:secretsmanager:us-east-1:692137657276:secret:production_altrx/*"
      Sid      = "SecretsManagerAccess"
    }]
    Version = "2012-10-17"
  })
  tags     = {}
  tags_all = {}
}

# __generated__ by Terraform from "AltrxReconcilerLambdaRole"
resource "aws_iam_role" "altrx_reconciler_lambda_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  description           = "Allows Lambda functions to call AWS services on your behalf."
  force_detach_policies = false
  max_session_duration  = 3600
  name                  = "AltrxReconcilerLambdaRole"
  path                  = "/"
  permissions_boundary  = null
  tags                  = {}
  tags_all              = {}
}


# =============================================================
# Consolidated Compute (ECS, Lambda, Amplify, ECR)
# =============================================================
# __generated__ by Terraform from "prod-worker"
resource "aws_ecr_repository" "prod_worker" {
  force_delete         = null
  image_tag_mutability = "MUTABLE"
  name                 = "prod-worker"
  tags                 = {}
  tags_all             = {}
  encryption_configuration {
    encryption_type = "AES256"
  }
  image_scanning_configuration {
    scan_on_push = false
  }
}

# __generated__ by Terraform from "Prod-Altrx/Prod-Backend"
resource "aws_ecs_service" "prod_backend" {
  availability_zone_rebalancing      = "ENABLED"
  cluster                            = "arn:aws:ecs:us-east-1:692137657276:cluster/Prod-Altrx"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1
  enable_ecs_managed_tags            = true
  enable_execute_command             = false
  force_delete                       = null
  force_new_deployment               = null
  health_check_grace_period_seconds  = 300
  iam_role                           = "/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"
  name                               = "Prod-Backend"
  platform_version                   = "1.4.0"
  propagate_tags                     = "NONE"
  scheduling_strategy                = "REPLICA"
  tags                               = {}
  tags_all                           = {}
  task_definition                    = "prod-backend:11"
  triggers                           = {}
  wait_for_steady_state              = null
  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE"
    weight            = 1
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller {
    type = "ECS"
  }
  load_balancer {
    container_name   = "backend"
    container_port   = 8000
    elb_name         = null
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:692137657276:targetgroup/Prod-Backend/9047f93ec179e5be"
  }
  network_configuration {
    assign_public_ip = false
    security_groups  = ["sg-023679ff04932ed99"]
    subnets          = ["subnet-03bf80a282f6614ed", "subnet-091fcae8d7ffe9a70"]
  }
}

# __generated__ by Terraform from "Prod-Altrx"
resource "aws_ecs_cluster" "production" {
  name     = "Prod-Altrx"
  tags     = {}
  tags_all = {}
  configuration {
    execute_command_configuration {
      kms_key_id = null
      logging    = "DEFAULT"
    }
  }
  setting {
    name  = "containerInsights"
    value = "enhanced"
  }
}

resource "aws_lambda_function" "altrx_reconciler" {
  architectures                      = ["x86_64"]
  code_signing_config_arn            = null
  description                        = null
  filename                           = null
  function_name                      = "altrx-reconciler"
  handler                            = null
  image_uri                          = "692137657276.dkr.ecr.us-east-1.amazonaws.com/altrx-reconciler:v-26-05-1527"
  kms_key_arn                        = null
  layers                             = []
  memory_size                        = 512
  package_type                       = "Image"
  publish                            = null
  replace_security_groups_on_destroy = null
  replacement_security_group_ids     = null
  reserved_concurrent_executions     = -1
  role                               = "arn:aws:iam::692137657276:role/AltrxReconcilerLambdaRole"
  runtime                            = null
  s3_bucket                          = null
  s3_key                             = null
  s3_object_version                  = null
  skip_destroy                       = false
  tags                               = {}
  tags_all                           = {}
  timeout                            = 600
  environment {
    variables = local.reconciler_env_vars
  }
  ephemeral_storage {
    size = 512
  }
  logging_config {
    application_log_level = null
    log_format            = "Text"
    log_group             = "/aws/lambda/altrx-reconciler"
    system_log_level      = null
  }
  tracing_config {
    mode = "PassThrough"
  }
}

# __generated__ by Terraform from "altrx-reconciler"
resource "aws_ecr_repository" "reconciler" {
  force_delete         = null
  image_tag_mutability = "MUTABLE"
  name                 = "altrx-reconciler"
  tags                 = {}
  tags_all             = {}
  encryption_configuration {
    encryption_type = "AES256"
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

# __generated__ by Terraform from "Prod-Altrx/Prod-Worker-Payment"
resource "aws_ecs_service" "prod_worker_payment" {
  availability_zone_rebalancing      = "ENABLED"
  cluster                            = "arn:aws:ecs:us-east-1:692137657276:cluster/Prod-Altrx"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 2
  enable_ecs_managed_tags            = true
  enable_execute_command             = false
  force_delete                       = null
  force_new_deployment               = null
  health_check_grace_period_seconds  = 0
  iam_role                           = "/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"
  name                               = "Prod-Worker-Payment"
  platform_version                   = "LATEST"
  propagate_tags                     = "NONE"
  scheduling_strategy                = "REPLICA"
  tags                               = {}
  tags_all                           = {}
  task_definition                    = "Prod-Worker-Payment:4"
  triggers                           = {}
  wait_for_steady_state              = null
  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE"
    weight            = 1
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller {
    type = "ECS"
  }
  network_configuration {
    assign_public_ip = true
    security_groups  = ["sg-043d1765e368b0eb9"]
    subnets          = ["subnet-03bf80a282f6614ed", "subnet-091fcae8d7ffe9a70"]
  }
}

# __generated__ by Terraform from "prod-backend"
resource "aws_ecr_repository" "prod_backend" {
  force_delete         = null
  image_tag_mutability = "MUTABLE"
  name                 = "prod-backend"
  tags                 = {}
  tags_all             = {}
  encryption_configuration {
    encryption_type = "AES256"
  }
  image_scanning_configuration {
    scan_on_push = false
  }
}

# __generated__ by Terraform from "dsx3g35brvnhn"
resource "aws_amplify_app" "production" {
  access_token                  = null # sensitive
  auto_branch_creation_patterns = []
  basic_auth_credentials        = null # sensitive
  build_spec                    = "version: 1\nfrontend:\n  phases:\n    preBuild:\n      commands:\n        - nvm use 20  # Use Node.js v20 as required by vite-builder\n        - npm ci\n    build:\n      commands:\n        - npx nuxi build\n  artifacts:\n    baseDirectory: .output\n    files:\n      - '**/*'\n  cache:\n    paths:\n      - node_modules/**/*"
  compute_role_arn              = null
  description                   = null
  enable_auto_branch_creation   = false
  enable_basic_auth             = false
  enable_branch_auto_build      = false
  enable_branch_auto_deletion   = false
  environment_variables = {
    APP_ENV                                = "production"
    ATTENTIVE_API_SECRET                   = "N0x4TkpNTTdnY1JxMFdxc3R2UnZ3S2NQalVSQ3Nya2VPQTBa"
    ATTENTIVE_SIGNUP_SOURCE_ID             = "1341729"
    BLOCKED_AFFIDS                         = "58"
    CAPI_CSRF_SECRET                       = "5d2cffa569ca17d687182f16af1ebadcfc52ea1727b559840773c202b6d87ee6"
    CAPI_PURCHASE_STRICT_MODE              = "true"
    CAREVALIDATE_WEBHOOK_SECRET            = "45645ee941c7e9c1c268e9d0b9fc06a99504e7f9b1ffee545e138c6abbc09ae4"
    CARE_VALIDATE_API_KEY_PROD             = "+o1jxQMfvrAiR91JGD5fl7F8gnVfjtGPCvWwvzOAB5Y="
    CARE_VALIDATE_API_KEY_STAGING          = "khwPiLCQQFlwtMmFmq2UETx7mNUP1w1sM1GpX6U+8OU="
    CARE_VALIDATE_API_URL_PROD             = "https://api.care360-next.carevalidate.com/api/v1/dynamic-case"
    CARE_VALIDATE_API_URL_STAGING          = "https://api-staging.care360-next.carevalidate.com/api/v1/dynamic-case"
    GLUCA_NEW_SEMA_01                      = "Glucasema1"
    GLUCA_NEW_SEMA_03                      = "Glucasema3"
    GLUCA_NEW_SEMA_06                      = "Glucasema6"
    GLUCA_NEW_SEMA_12                      = "Glucasema12"
    GLUCA_NEW_TIRZ_01                      = "GlucaTirz1"
    GLUCA_NEW_TIRZ_03                      = "GlucaTirz3"
    GLUCA_NEW_TIRZ_06                      = "GlucaTirz6"
    GLUCA_NEW_TIRZ_12                      = "GlucaTirz12"
    GLUCA_SEMA_03                          = "glucasema03"
    GLUCA_SEMA_06                          = "glucasema06"
    GLUCA_SEMA_12                          = "glucasema12"
    GLUCA_TIRZ_03                          = "glucatirz03"
    GLUCA_TIRZ_06                          = "glucatirz06"
    GLUCA_TIRZ_12                          = "glucatirz12"
    MEMORIAL_OFFER_ENABLED                 = "false"
    NODE_ENV                               = "production"
    NORTHBEAM_API_KEY_PROD                 = "88b8b757-14f3-46e9-ac7a-1f5f23f23699"
    NORTHBEAM_CLIENT_ID_PROD               = "84aeb136-c685-4f16-b6ba-8cdb2bf95cb1"
    NUXT_AC_API_KEY                        = "cbaee37b274fd99e7e653445e85f723c5daa48dd16b33041ff45829f601e80ccf829c667"
    NUXT_AC_API_URL                        = "https://altrx.api-us1.com"
    NUXT_FACEBOOK_ACCESS_TOKEN             = "EAARQxZAZBji0sBQh5AY47GPTT6vUmw7js9DZAnxeZCRjzkTziZANSPMFODZBBHQSlALYhzZBIYk8cXPLmLlDA1BKt6GL1xGo6HmZBAwLjHW9TbdZBz8c1Yw4XRF6i8ZBwQ3iKtEyNZC0pUlUbn7p9ZAVoaEjD5LZAwqPINd04u0kxf2ZACs1QY6O4OiPtGF2SGJPsxMq6X1gZDZD"
    NUXT_FACEBOOK_CLIENT_ACCESS_TOKEN      = "EAAWVvKkgHHsBQpaa82iE0e4aunfc3uiZAIKFWUZBDiZAGwHSn1XbN4oG5EreMV5ZCcxdZANgzAjTtBqXZCrKG42fnHJMt4LETL3kHmZAhdHdvIP6s1EXLHxwZByhnZCROTpGAZBGZAB70jS6gS4XgOrdUExPYUZCTik85Yes54zrzPVjBVw5KYFb5nuxfcOK8Hf0NQZDZD"
    NUXT_PUBLIC_BACKEND_BASE_URL           = "https://api.altrx.com"
    NUXT_PUBLIC_CUSTOMERIO_WRITE_KEY       = "74db6f5e8e91bec96fc1"
    NUXT_PUBLIC_EF_API_KEY                 = "BwtATVAWTzqgE5uuSljvvg"
    NUXT_PUBLIC_EF_BASE_URL                = "https://api.eflow.team/v1"
    NUXT_PUBLIC_FINGERPRINT_API_KEY        = "906b730d0b25ae8e2af1fefec8a3ef3c"
    NUXT_PUBLIC_OFFER_END_DATETIME         = "2026-05-31T04:00:00Z"
    NUXT_PUBLIC_ORGANIZATION_ID            = "f3c75a6e-bf79-4b14-9829-770f9f82763e"
    NUXT_PUBLIC_SENTRY_DSN                 = "https://20734d967249f18b0aa8c8eec466a528@o4506247411400704.ingest.us.sentry.io/4510974156603393"
    NUXT_PUBLIC_SUPABASE_URL               = "https://bajpgkwpuhebwdrokrcg.supabase.co"
    NUXT_TIKTOK_API_KEY                    = "79143f1c9f28a86b70a4277d6a13f882544a87cb"
    PAYPAL_CLIENT_ID_LIVE                  = "AW9U7PgwtQyIJgJcSAGWc12VWsUME6arNvyZ6VYE37hzBOfTtNqwQErclnma2INar0ZxnQoIQxj5at59"
    PAYPAL_CLIENT_ID_SANDBOX               = "AfAvWvaJf7jJPd0sWe9JRBP-dPv_vIivhfrCs7ghwmXu8g4P_otGykiqkqyVvLBGGrdQN48jMhz2Ozq3"
    PAYPAL_SECRET_KEY_LIVE                 = "ECIDQdCq-DTjpODdqWCQ5saGGor0aXz03TqZBh9cbTQOPqjDonPCCAo9pYef_x5VBrFuplv-2pImggZh"
    PAYPAL_SECRET_KEY_SANDBOX              = "EB2VX-sIWtMLiWVYq7DqqEhCfpQqw9Z2AhztS1k00WrVL1tcsgBoF6PN9W7xWH50NY6LizFkSuW6xYDp"
    SEMAGLUTIDE_12_MONTH_CODE              = "THRIVE12"
    SEMAGLUTIDE_1_MONTH_CODE               = "THRIVE01"
    SEMAGLUTIDE_3_MONTH_CODE               = "THRIVE03"
    SEMAGLUTIDE_6_MONTH_CODE               = "THRIVE06"
    SPECIAL_SMS_10_CODE                    = "SPECIAL_SMS_10_CODE=SPECIALSMS10"
    SPECIAL_SMS_20_CODE                    = "SPECIALSMS20"
    SPRING_OFFER_ENABLED                   = "true"
    STRIPE_PUBLISHABLE_KEY_PROD            = "pk_live_51HqSIiKAXrtjbq2dtXcGLkFqhqPquraau6jRB8nDCrDVIGj7me2ZEAiQxZNwuG9A7Y1Gzn6vg8xslQuCpoTByMKd00cmPemstt"
    STRIPE_PUBLISHABLE_KEY_STAGING         = "pk_test_51HqSIiKAXrtjbq2dUipJMaSqisS96Auqj0wFVcuuwtD75gC0Jof2HIlmG8RoGYLlAToyPeIDOqMsjTLUfgXLNh1U00lrHRJ5Bl"
    SUPABASE_ANON_KEY                      = "sb_publishable_Pi-WGAF8RF2pUHnBmhuWUQ_E6sjjwQc"
    TELLESCOPE_STRIPE_PUBLISHABLE_KEY_LIVE = "pk_live_51TM96P5wzaB24K2YuMY0hPOSvzVvnZqyK1EAtTitBxovNcm3aMdHOZy2BFqe1gKR7sN2Hz7iqBEYS7lJxPK6jfyq00U4nE8MRc"
    TIRZEPATIDE_12_MONTH_CODE              = "BREAKTHRU12"
    TIRZEPATIDE_1_MONTH_CODE               = "BREAKTHRU01"
    TIRZEPATIDE_3_MONTH_CODE               = "BREAKTHRU03"
    TIRZEPATIDE_6_MONTH_CODE               = "BREAKTHRU06"
    UGC2026DEAL                            = "ugc2026deal"
    V9_SAVE_10_CODE                        = "V9SAVE10"
    V9_SAVE_15_CODE                        = "V9SAVE15"
    V9_SAVE_20_CODE                        = "V9SAVE20"
    WEB3FORMS_ACCESS_KEY                   = "bcd12197-4ec8-4054-924b-a6bd997589ae"
    WHITECOAT_STRIPE_PUBLISHABLE_KEY_LIVE  = "pk_live_51TUTcZ92ycriP3hHApoRlDsqYSUimlEH84ydRDNjpCIrAuQnm3jwwpkX6sberJyX4MHZf1nCxnlkPFPfUjKG4cnM00wunwcvHZ"
  }
  iam_service_role_arn = "arn:aws:iam::692137657276:role/service-role/AmplifySSRLoggingRole-638507c3-6940-4947-b58d-16f5ca25c35a"
  name                 = "Production_Altrx"
  oauth_token          = null # sensitive
  platform             = "WEB_COMPUTE"
  repository           = "https://github.com/trinity-healthcare-supply/altrx"
  tags                 = {}
  tags_all             = {}
  cache_config {
    type = "AMPLIFY_MANAGED_NO_COOKIES"
  }
  custom_rule {
    condition = null
    source    = "https://altrx.com"
    status    = "302"
    target    = "https://www.altrx.com"
  }
  custom_rule {
    condition = null
    source    = "/blogs"
    status    = "200"
    target    = "https://blogs.altrx.com"
  }
  custom_rule {
    condition = null
    source    = "/blogs/<*>"
    status    = "200"
    target    = "https://blogs.altrx.com/<*>"
  }
  custom_rule {
    condition = null
    source    = "/<*>"
    status    = "404-200"
    target    = "/index.html"
  }
}

