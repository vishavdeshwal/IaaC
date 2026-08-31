variable "aws_region" {
  type        = string
  description = "The target AWS region for the bootstrap backend resources."
  default     = "eu-west-1"
}

variable "aws_profile" {
  type        = string
  description = "The AWS CLI profile to authenticate with."
  default     = "bsl"
}

variable "project" {
  type        = string
  description = "The project name prefix applied to the S3 bucket."
  default     = "bsl"
}
