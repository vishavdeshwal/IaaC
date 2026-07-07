variable "name" {
  type        = string
  description = "Name for the ECR repository"
}

variable "image_tag_mutability" {
  type        = string
  default     = "MUTABLE"
  description = "The tag mutability setting for the repository. Must be one of: MUTABLE or IMMUTABLE."
}

variable "scan_on_push" {
  type        = bool
  default     = true
  description = "Indicates whether images are scanned after being pushed to the repository"
}

variable "encryption_type" {
  type        = string
  default     = "AES256"
  description = "The encryption type to use for the repository. Must be one of: AES256 or KMS."
}

variable "kms_key" {
  type        = string
  default     = null
  description = "The ARN of the KMS key to use when encryption_type is KMS. If not specified, uses the default AWS managed key for ECR."
}

variable "lifecycle_policy_enabled" {
  type        = bool
  default     = false
  description = "Whether to attach a lifecycle policy to automatically clean up old/untagged images"
}

variable "max_image_count" {
  type        = number
  default     = 30
  description = "The maximum number of tagged images to keep. Older images will be cleaned up if lifecycle_policy_enabled is true."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. staging, production)"
}

variable "project" {
  type        = string
  description = "Project name"
}

variable "name_override" {
  type    = string
  default = null
}

