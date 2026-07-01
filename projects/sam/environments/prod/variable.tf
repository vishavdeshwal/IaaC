variable "aws_region" {
    type    = string
    default = "ap-south-1"
}
variable "aws_profile" {
    type    = string
    default = "sam"
}

variable "vpc_cidr" {
    type = string
}

variable "environment" {
    type    = string
    default = "prod"
}

variable "project" {
    type    = string
    default = "SAMMMM"
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


variable "secret_gupshup_hmac_secret" {
  type        = string
  sensitive   = true
  description = "The secret Gupshup HMAC credentials key"
  default     = "dummy-gupshup-hmac-secret"
}

variable "secret_gupshup_token" {
  type        = string
  sensitive   = true
  description = "The secret Gupshup access token"
  default     = "dummy-gupshup-token"
}

variable "secret_clevertap_passcode" {
  type        = string
  sensitive   = true
  description = "The secret Clevertap passcode"
  default     = "dummy-clevertap-passcode"
}

variable "bastion_key_name" {
  type        = string
  default     = null
  description = "The SSH key pair name for the EC2 bastion instance"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listeners on the ALB"
}

variable "webhook_secret" {
  type        = string
  sensitive   = true
  description = "HMAC secret used to verify incoming webhook payloads"
}

variable "secret_google_api_key" {
  type        = string
  sensitive   = true
  description = "Google API key (Gemini) stored in Secrets Manager"
}

variable "secret_openai_api_key" {
  type        = string
  sensitive   = true
  description = "OpenAI API key stored in Secrets Manager"
  default     = ""
}

variable "secret_deeptag_api_key" {
  type        = string
  sensitive   = true
  description = "DeepTag API key stored in Secrets Manager"
}

variable "secret_email_smtp_password" {
  type        = string
  sensitive   = true
  description = "SMTP password for outbound email stored in Secrets Manager"
}

variable "secret_gupshup_numbers" {
  type        = string
  sensitive   = true
  description = "Gupshup whitelisted sender numbers stored in Secrets Manager"
  default     = ""
}
