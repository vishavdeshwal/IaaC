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
    default = "prod"
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
  description = "Environment variables for the altrx-reconciler Lambda function"
  sensitive   = true
}

variable "amplify_env_vars" {
  type        = map(string)
  description = "Environment variables for the Amplify App"
  sensitive   = true
}

variable "ecs_launch_type" {
  type        = string
  default     = null
  description = "Launch type for ECS Services (null when using capacity provider strategies)"
}

variable "sns_topic_arn" {
  type        = string
  description = "The ARN of the pre-provisioned SNS topic to send alerts to"
}
