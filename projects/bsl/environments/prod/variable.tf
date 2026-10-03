variable "aws_region" {
  type        = string
  description = "AWS deployment region"
  default     = "eu-west-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile name"
  default     = "bsl"
}

variable "project" {
  type        = string
  description = "Project name"
  default     = "bsl"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "prod"
}

variable "domain_name" {
  type        = string
  description = "Base domain name for production"
  default     = "bubkasportslab.com"
}

variable "manage_route53_records" {
  type        = bool
  description = "Whether to create and manage Route 53 DNS records for bubkasportslab.com"
  default     = true
}

// -------------------------------------------------------------
// Networking Variables
// -------------------------------------------------------------

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.2.0.0/16"
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "Enable DNS hostnames in VPC"
  default     = true
}

variable "enable_dns_support" {
  type        = bool
  description = "Enable DNS support in VPC"
  default     = true
}

variable "instance_tenancy" {
  type        = string
  description = "VPC instance tenancy"
  default     = "default"
}

variable "public_subnets" {
  type = map(object({
    cidr     = string
    az_index = number
  }))
  description = "Public subnets configuration"
}

variable "private_subnets" {
  type = map(object({
    cidr     = string
    az_index = number
  }))
  description = "Private subnets configuration for App and DB tiers"
}

// -------------------------------------------------------------
// Compute & Bastion Variables
// -------------------------------------------------------------

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to insert into Bastion and ERP instances authorized_keys"
  default     = ""
}

variable "bastion_instance_type" {
  type        = string
  description = "EC2 instance type for Bastion host"
  default     = "t3.small"
}

variable "erp_instance_type" {
  type        = string
  description = "EC2 instance type for ERP server"
  default     = "t3.xlarge"
}

variable "erp_root_volume_size" {
  type        = number
  description = "Root EBS volume size in GB for ERP server"
  default     = 100
}

// -------------------------------------------------------------
// Load Balancing & SSL Certificates
// -------------------------------------------------------------

variable "certificate_arn" {
  type        = string
  description = "ACM Certificate ARN in eu-west-1 for ALB HTTPS listener"
  default     = null
}

variable "cdn_acm_certificate_arn" {
  type        = string
  description = "ACM Certificate ARN in us-east-1 for CloudFront CDN"
  default     = null
}

variable "health_check_path" {
  type        = string
  description = "Default health check path for ALB target groups"
  default     = "/health"
}

// -------------------------------------------------------------
// S3 & CloudFront
// -------------------------------------------------------------

variable "media_bucket_name" {
  type        = string
  description = "Name for the S3 media and assets bucket"
  default     = "bsl-prod-media-assets-eu-west-1"
}

// -------------------------------------------------------------
// Database Variables (Single-AZ)
// -------------------------------------------------------------

variable "mariadb_engine_version" {
  type        = string
  description = "MariaDB engine version for ERP database"
  default     = "11.4.5"
}

variable "mariadb_instance_class" {
  type        = string
  description = "Instance class for ERP MariaDB RDS"
  default     = "db.t4g.medium"
}

variable "master_db_user_name" {
  type        = string
  description = "Master username for ERP MariaDB database"
  default     = "admin"
}

variable "master_db_user_pass" {
  type        = string
  description = "Master password for ERP MariaDB database"
  sensitive   = true
}

variable "postgres_engine_version" {
  type        = string
  description = "PostgreSQL engine version for Saleor/Strapi and Backend databases"
  default     = "15.17"
}

variable "postgres_instance_class" {
  type        = string
  description = "Instance class for PostgreSQL RDS instances"
  default     = "db.t4g.medium"
}

variable "postgres_master_user_name" {
  type        = string
  description = "Master username for Saleor/Strapi PostgreSQL database"
  default     = "postgres"
}

variable "postgres_master_user_pass" {
  type        = string
  description = "Master password for Saleor/Strapi PostgreSQL database"
  sensitive   = true
}

variable "backend_postgres_master_user_name" {
  type        = string
  description = "Master username for Backend PostgreSQL database"
  default     = "postgres"
}

variable "backend_postgres_master_user_pass" {
  type        = string
  description = "Master password for Backend PostgreSQL database"
  sensitive   = true
}

// -------------------------------------------------------------
// Redis Variables
// -------------------------------------------------------------

variable "redis_node_type" {
  type        = string
  description = "Node type for ElastiCache Redis clusters"
  default     = "cache.t4g.medium"
}

variable "redis_engine_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.1"
}

// -------------------------------------------------------------
// Application & ECS Secrets & Env Vars (Segregated)
// -------------------------------------------------------------

variable "backend_secrets" {
  type        = map(string)
  description = "Backend sensitive secrets stored in AWS Secrets Manager"
  default     = {}
  sensitive   = true
}

variable "backend_env_vars" {
  type        = map(string)
  description = "Backend non-sensitive environment variables injected directly into Task Definition"
  default     = {}
}

variable "saleor_secrets" {
  type        = map(string)
  description = "Saleor sensitive secrets stored in AWS Secrets Manager"
  default     = {}
  sensitive   = true
}

variable "saleor_env_vars" {
  type        = map(string)
  description = "Saleor non-sensitive environment variables injected directly into Task Definition"
  default     = {}
}

variable "strapi_secrets" {
  type        = map(string)
  description = "Strapi sensitive secrets stored in AWS Secrets Manager"
  default     = {}
  sensitive   = true
}

variable "strapi_env_vars" {
  type        = map(string)
  description = "Strapi non-sensitive environment variables injected directly into Task Definition"
  default     = {}
}
