variable "aws_region" {
  type = string
}
variable "aws_profile" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "instance_tenancy" {
  type    = string
  default = "default"
}

variable "enable_dns_hostnames" {
  type    = bool
  default = true
}

variable "enable_dns_support" {
  type    = bool
  default = true
}

variable "public_subnets" {
  type = map(object({
    cidr     = string
    az_index = number
  }))
}

variable "private_subnets" {
  type = map(object({
    cidr     = string
    az_index = number
  }))
}

variable "master_db_user_name" {
  type = string
}

variable "master_db_user_pass" {
  type = string
}

variable "mariadb_user_name" {
  type    = string
  default = "mariadbadmin"
}

variable "mariadb_user_pass" {
  type = string
}

variable "health_check_path" {
  type = string
}


variable "certificate_arn" {
  type        = string
  description = "The ARN of the ACM certificate for the ALB"
}

variable "backend_env_vars" {
  type        = map(string)
  description = "Unsecure environment variables for the Node backend"
  default     = {}
}

variable "backend_secrets" {
  type        = map(string)
  description = "Sensitive secrets for the Node backend, to be stored in Secrets Manager"
  default     = {}
}

variable "saleor_secrets" {
  type        = map(string)
  description = "Sensitive secrets for the Saleor app, to be stored in Secrets Manager"
  default     = {}
}

variable "saleor_env_vars" {
  type        = map(string)
  description = "Unsecure environment variables for the Saleor app"
  default     = {}
}