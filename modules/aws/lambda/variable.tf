variable "function_name" {
  type        = string
  description = "Name of the Lambda function"
}

variable "runtime" {
  type        = string
  default     = "python3.12"
  description = "Lambda runtime (e.g. python3.12, nodejs20.x, java17)"
}

variable "handler" {
  type        = string
  default     = "index.handler"
  description = "Function entrypoint (filename.function_name)"
}

variable "memory_size" {
  type        = number
  default     = 128
  description = "Amount of memory in MB"
}

variable "timeout" {
  type        = number
  default     = 30
  description = "Function timeout in seconds (max 900)"
}

# --- Deployment Package (choose one of: filename, s3_bucket+s3_key, or image_uri) ---

variable "filename" {
  type        = string
  default     = null
  description = "Path to the local zip file containing function code. Use when deploying from local files."
}

variable "s3_bucket" {
  type        = string
  default     = null
  description = "S3 bucket name containing the deployment package"
}

variable "s3_key" {
  type        = string
  default     = null
  description = "S3 object key for the deployment package"
}

variable "image_uri" {
  type        = string
  default     = null
  description = "ECR image URI for container-based Lambda"
}

variable "source_code_hash" {
  type        = string
  default     = null
  description = "Base64-encoded SHA256 hash of the package file. Used to detect changes."
}

# --- Environment Variables ---

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Environment variables to pass to the Lambda function"
}

# --- VPC (optional — Lambda runs outside a VPC by default) ---

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "Subnet IDs for VPC-connected Lambda. Empty list = no VPC."
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "Security group IDs for VPC-connected Lambda"
}

# --- IAM ---

variable "additional_policy_arns" {
  type        = list(string)
  default     = []
  description = "Additional IAM policy ARNs to attach to the Lambda execution role"
}

# --- Layers ---

variable "layers" {
  type        = list(string)
  default     = []
  description = "List of Lambda layer ARNs to attach (max 5)"
}

variable "reserved_concurrent_executions" {
  type        = number
  default     = -1
  description = "Reserved concurrency. -1 means unreserved. 0 throttles the function."
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "name_override" {
  type    = string
  default = null
}

variable "role_name_override" {
  type    = string
  default = null
}

variable "ecr_repository_name" {
  type        = string
  default     = null
  description = "The name of the ECR repository to attach Lambda ECR image retrieval policy"
}

variable "ecr_repository_arn" {
  type        = string
  default     = null
  description = "The ARN of the ECR repository for Lambda execution role to read from"
}

