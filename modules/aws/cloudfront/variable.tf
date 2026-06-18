variable "s3_bucket_id" {
  type        = string
  description = "The ID/Name of the S3 bucket to connect to CloudFront"
}

variable "s3_bucket_regional_domain_name" {
  type        = string
  description = "The regional domain name of the S3 bucket"
}

variable "environment" {
  type        = string
  description = "The environment name (e.g. staging, prod)"
}

variable "project" {
  type        = string
  description = "The project name"
}
