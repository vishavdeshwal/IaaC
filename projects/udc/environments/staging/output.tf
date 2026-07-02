# ==============================================================================
# NETWORKING OUTPUTS
# ==============================================================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Map of public subnets"
  value       = module.subnets.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Map of private subnets"
  value       = module.subnets.private_subnet_ids
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = module.nat_gateway.nat_gateway_id
}

# ==============================================================================
# SECURITY GROUP OUTPUTS
# ==============================================================================

output "alb_security_group_id" {
  description = "The ID of the ALB Security Group"
  value       = module.alb_sg.security_group_id
}

output "app_security_group_id" {
  description = "The ID of the Application Security Group"
  value       = module.app_sg.security_group_id
}

# ==============================================================================
# LOAD BALANCER OUTPUTS
# ==============================================================================

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "The Route53 Zone ID of the ALB"
  value       = module.alb.alb_zone_id
}

# ==============================================================================
# ECS CLUSTER OUTPUTS
# ==============================================================================

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = module.ecs_cluster.cluster_arn
}

# ==============================================================================
# IAM ROLES
# ==============================================================================

output "ecs_execution_role_arn" {
  description = "ARN of the ECS Execution Role"
  value       = module.ecs_execution_role.role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS Task Role"
  value       = module.ecs_task_role.role_arn
}

# ==============================================================================
# ECR REPOSITORIES
# ==============================================================================

output "ecr_repository_be_url" {
  description = "URL of the udc-be ECR repository"
  value       = module.ecr_be.repository_url
}

output "ecr_repository_truedesk_url" {
  description = "URL of the udc-truedesk ECR repository"
  value       = module.ecr_truedesk.repository_url
}

output "ecr_repository_master_web_url" {
  description = "URL of the udc-master-web ECR repository"
  value       = module.ecr_master_web.repository_url
}

output "ecr_repository_master_admin_url" {
  description = "URL of the udc-master-admin ECR repository"
  value       = module.ecr_master_admin.repository_url
}

output "ecr_repository_student_web_url" {
  description = "URL of the udc-student-web ECR repository"
  value       = module.ecr_student_web.repository_url
}

output "ecr_repository_instructor_web_url" {
  description = "URL of the udc-instructor-web ECR repository"
  value       = module.ecr_instructor_web.repository_url
}

# ==============================================================================
# SQS QUEUES
# ==============================================================================

output "sqs_dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = module.sqs_dlq.queue_url
}

output "sqs_queue_url" {
  description = "URL of the main UDC Queue"
  value       = module.sqs_queue.queue_url
}

output "sqs_session_unlock_queue_url" {
  description = "URL of the Session Unlock Queue"
  value       = module.sqs_session_unlock.queue_url
}
