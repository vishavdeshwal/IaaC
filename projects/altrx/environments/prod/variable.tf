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

variable "meta_access_token" {
    type      = string
    sensitive = true
}

variable "slack_webhook_url" {
    type      = string
    sensitive = true
}

variable "stripe_tellescope_secret_key" {
    type      = string
    sensitive = true
}

variable "stripe_tellescope_webhook_secret" {
    type      = string
    sensitive = true
}

variable "stripe_whitecoat_secret_key" {
    type      = string
    sensitive = true
}

variable "stripe_whitecoat_webhook_secret" {
    type      = string
    sensitive = true
}

variable "tellescope_tellescope_api_key" {
    type      = string
    sensitive = true
}

variable "tellescope_whitecoat_api_key" {
    type      = string
    sensitive = true
}


