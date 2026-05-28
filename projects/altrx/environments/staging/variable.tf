variable "aws_region" {
    type    = string
    default = "ap-south-1"
}

variable "aws_profile" {
    type    = string
    default = "altrx"
}

variable "environment" {
    type    = string
    default = "staging"
}

variable "project" {
    type    = string
    default = "ALTRX"
}

variable "vpc_cidr" {
    type    = string
    default = "10.1.0.0/16"
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

variable "reconciler_env_vars" {
  type        = map(string)
  description = "Environment variables for the altrx-reconciler-staging Lambda function"
  sensitive   = true
}

variable "ecs_launch_type" {
  type        = string
  default     = "FARGATE"
  description = "The launch type for ECS services (FARGATE or EC2)"
}

variable "bastion_key_name" {
  type        = string
  default     = null
  description = "Name of the existing AWS SSH key pair to attach to the Bastion. If null, access can still be obtained via AWS SSM."
}

