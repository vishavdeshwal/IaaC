variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g. preprod, prod)"
}

variable "project" {
  type        = string
  description = "Project name"
}

variable "manage_public_access_block" {
  type        = bool
  default     = true
  description = "Whether to create aws_s3_bucket_public_access_block"
}

variable "block_public_acls" {
  type        = bool
  default     = true
  description = "Whether Amazon S3 should block public ACLs for this bucket"
}

variable "block_public_policy" {
  type        = bool
  default     = true
  description = "Whether Amazon S3 should block public bucket policies for this bucket"
}

variable "ignore_public_acls" {
  type        = bool
  default     = true
  description = "Whether Amazon S3 should ignore public ACLs for this bucket"
}

variable "restrict_public_buckets" {
  type        = bool
  default     = true
  description = "Whether Amazon S3 should restrict public bucket policies for this bucket"
}

variable "enable_public_read" {
  type        = bool
  default     = false
  description = "Whether to attach a public s3:GetObject bucket policy"
}

variable "enable_cors" {
  type        = bool
  default     = false
  description = "Whether to configure CORS for this bucket"
}

variable "cors_allowed_headers" {
  type        = list(string)
  default     = ["*"]
  description = "List of allowed headers for CORS"
}

variable "cors_allowed_methods" {
  type        = list(string)
  default     = ["GET", "PUT", "POST", "DELETE", "HEAD"]
  description = "List of allowed HTTP methods for CORS"
}

variable "cors_allowed_origins" {
  type        = list(string)
  default     = ["*"]
  description = "List of allowed origins for CORS"
}

variable "cors_expose_headers" {
  type        = list(string)
  default     = ["ETag"]
  description = "List of headers exposed by CORS"
}

variable "cors_max_age_seconds" {
  type        = number
  default     = 3000
  description = "Max age seconds for CORS preflight cache"
}

variable "enable_alb_access_logs_policy" {
  type        = bool
  default     = false
  description = "Whether to attach an S3 bucket policy allowing AWS ELB and log delivery service to write access logs"
}

variable "lifecycle_expiration_days" {
  type        = number
  default     = null
  description = "Number of days after which objects in the bucket automatically expire"
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Whether all objects should be deleted from the bucket so that the bucket can be destroyed without error"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags for the S3 bucket"
}
