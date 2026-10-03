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

variable "aliases" {
  type        = list(string)
  description = "Extra CNAMEs (alternate domain names), if any, for this distribution"
  default     = []
}

variable "acm_certificate_arn" {
  type        = string
  description = "The ARN of the AWS Certificate Manager certificate in us-east-1"
  default     = null
}

variable "default_root_object" {
  type        = string
  description = "The object that you want CloudFront to return when an end user requests the root URL"
  default     = ""
}

variable "price_class" {
  type        = string
  description = "The price class for this distribution (e.g. PriceClass_100, PriceClass_200, PriceClass_All)"
  default     = "PriceClass_100"
}

variable "ssl_support_method" {
  type        = string
  description = "How you want CloudFront to serve HTTPS requests: sni-only or vip"
  default     = "sni-only"
}

variable "minimum_protocol_version" {
  type        = string
  description = "The minimum version of the SSL protocol that you want CloudFront to use for HTTPS connections"
  default     = "TLSv1.2_2021"
}
