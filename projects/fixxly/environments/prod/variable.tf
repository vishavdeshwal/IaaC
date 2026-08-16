variable "aws_region" {
  type        = string
  description = "AWS Region for deployment"
  default     = "ap-south-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS Profile for deployment"
  default     = "fixxly"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. preprod, prod)"
  default     = "prod"
}

variable "project" {
  type        = string
  description = "Project name"
  default     = "fixxly"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR Block"
  default     = "10.0.0.0/16"
}

variable "instance_tenancy" {
  type        = string
  description = "Instance tenancy mode"
  default     = "default"
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

variable "public_subnets" {
  type = map(object({
    cidr     = string
    az_index = number
  }))
  description = "Public subnets configuration map"
}

variable "private_subnets" {
  type = map(object({
    cidr     = string
    az_index = number
  }))
  description = "Private subnets configuration map"
}

# --- Database Variables ---

variable "mariadb_engine_version" {
  type        = string
  description = "Engine version for MariaDB RDS"
  default     = "10.11"
}

variable "master_db_user_name" {
  type        = string
  description = "Master username for RDS MariaDB"
  default     = "dbadmin"
}

variable "master_db_user_pass" {
  type        = string
  description = "Master password for RDS MariaDB"
  sensitive   = true
}

variable "postgres_engine_version" {
  type        = string
  description = "Engine version for PostgreSQL RDS"
  default     = "15.6"
}

variable "postgres_master_user_name" {
  type        = string
  description = "Master username for RDS PostgreSQL"
  default     = "postgres"
}

variable "postgres_master_user_pass" {
  type        = string
  description = "Master password for RDS PostgreSQL"
  sensitive   = true
}

variable "backend_postgres_master_user_name" {
  type        = string
  description = "Master username for Dedicated Backend RDS PostgreSQL"
  default     = "postgres"
}

variable "backend_postgres_master_user_pass" {
  type        = string
  description = "Master password for Dedicated Backend RDS PostgreSQL"
  sensitive   = true
}

# --- ALB & App Variables ---

variable "health_check_path" {
  type        = string
  description = "Default ALB health check path"
  default     = "/healthz"
}

variable "certificate_arn" {
  type        = string
  description = "ACM Certificate ARN for HTTPS listener on ALB"
  default     = ""
}

variable "backend_env_vars" {
  type        = map(string)
  description = "Environment variables for Strapi / Node backend"
  default     = {}
}

variable "backend_secrets" {
  type        = map(string)
  description = "Sensitive secrets stored in Secrets Manager for Strapi / Node backend"
  default     = {}
}

variable "saleor_env_vars" {
  type        = map(string)
  description = "Environment variables for Saleor app"
  default     = {}
}

variable "saleor_secrets" {
  type        = map(string)
  description = "Sensitive secrets stored in Secrets Manager for Saleor app"
  default     = {}
}

variable "frontend_env_vars" {
  type        = map(string)
  description = "Environment variables for Web Frontend App"
  default     = {}
}

variable "strapi_secrets" {
  type        = map(string)
  description = "Sensitive secrets stored in Secrets Manager for Strapi CMS"
  default     = {}
}

variable "ec2_key_name" {
  type        = string
  description = "EC2 Key Pair name for SSH access"
  default     = ""
}

# --- Service Port Variables ---

variable "frontend_port" {
  type    = number
  default = 3000
}

variable "consumer_bff_port" {
  type    = number
  default = 3020
}

variable "auth_service_port" {
  type    = number
  default = 3001
}

variable "product_service_port" {
  type    = number
  default = 3003
}

variable "order_service_port" {
  type    = number
  default = 3004
}

variable "cart_service_port" {
  type    = number
  default = 3005
}

variable "inventory_service_port" {
  type    = number
  default = 3006
}

variable "cms_bridge_port" {
  type    = number
  default = 3007
}

variable "coupon_service_port" {
  type    = number
  default = 3008
}

variable "notification_service_port" {
  type    = number
  default = 3009
}

variable "payment_service_port" {
  type    = number
  default = 3010
}

variable "erp_sync_service_port" {
  type    = number
  default = 3011
}

variable "wallet_service_port" {
  type    = number
  default = 3012
}

variable "assets_service_port" {
  type    = number
  default = 3013
}

variable "serviceability_service_port" {
  type    = number
  default = 3014
}
