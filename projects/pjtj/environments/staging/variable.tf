variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "ap-south-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile name"
  default     = "pjtj"
}

variable "project" {
  type        = string
  description = "Project name"
  default     = "pjtj"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "staging"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
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
