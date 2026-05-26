variable "aws_region" {
  type        = string
  description = "The target AWS region for the bootstrap backend resources."
  default     = "ap-south-1"
}

variable "aws_profile" {
  type        = string
  description = "The AWS CLI profile to authenticate with."
  default     = "altrx"
}

variable "project" {
  type        = string
  description = "The project name prefix applied to the S3 bucket tags."
  default     = "ALTRX"
}
