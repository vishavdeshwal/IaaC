variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "bsl"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "bsl"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnets" {
  description = "Public subnets CIDR blocks (one per AZ across 2 AZs)"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnets CIDR blocks (one per AZ across 2 AZs)"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

variable "media_bucket_name" {
  description = "Name of the S3 bucket for media and assets"
  type        = string
  default     = "bsl-staging-media-assets-148552"
}

variable "cdn_aliases" {
  description = "Custom domain aliases (CNAMEs) for the CloudFront CDN distribution"
  type        = list(string)
  default     = ["marketing-web.bubkasportslab.com"]
}

variable "cdn_acm_certificate_arn" {
  description = "ACM Certificate ARN in us-east-1 for CloudFront (leave null to use default cloudfront certificate or override)"
  type        = string
  default     = null
}
