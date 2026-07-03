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

variable "backend_secrets" {
  description = "A map of sensitive environment variables for the backend"
  type        = map(string)
}

variable "frontend_secrets" {
  description = "A map of sensitive environment variables for the frontends"
  type        = map(string)
}

variable "docdb_master_username" {
  type        = string
  description = "Master username for DocumentDB"
  default     = "udcadmin"
}

variable "docdb_master_password" {
  type        = string
  description = "Master password for DocumentDB"
  sensitive   = true
}

variable "ses_email_address" {
  description = "The email address to verify for SES"
  type        = string
}
