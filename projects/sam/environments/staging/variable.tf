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

variable "health_check_path" {
    type = string
}