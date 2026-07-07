variable "name" {
  type        = string
  description = "Name of the Amplify app (matches AWS console name)"
}

variable "repository" {
  type        = string
  description = "GitHub repository URL"
}

variable "platform" {
  type        = string
  default     = "WEB_COMPUTE"
  description = "Amplify platform (WEB_COMPUTE for SSR / Nuxt)"
}

variable "iam_service_role_arn" {
  type        = string
  default     = null
  description = "ARN of the IAM role for Amplify SSR logging and secret access"
}

variable "build_spec" {
  type        = string
  default     = null
  description = "YAML build spec content. If null, uses app-level amplify.yml from repo."
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Non-sensitive env vars set on the Amplify app (e.g. SSM_PREFIX, AWS_REGION). Sensitive vars live in SSM Parameter Store."
  sensitive   = false
}

variable "enable_branch_auto_build" {
  type        = bool
  default     = false
  description = "Whether to auto-build on all branch pushes"
}

variable "enable_branch_auto_deletion" {
  type        = bool
  default     = false
  description = "Whether to auto-delete branches removed in the repo"
}

variable "cache_config_type" {
  type        = string
  default     = "AMPLIFY_MANAGED_NO_COOKIES"
  description = "Cache configuration type for the Amplify app"
}

variable "custom_rules" {
  type = list(object({
    source    = string
    target    = string
    status    = string
    condition = optional(string, null)
  }))
  default     = []
  description = "URL rewrite and redirect rules"
}

variable "branches" {
  type = map(object({
    stage                       = string
    enable_auto_build           = optional(bool, true)
    enable_pull_request_preview = optional(bool, false)
    environment_variables       = optional(map(string), {})
  }))
  default     = {}
  description = "Map of branch_name => branch config to create"
}

variable "custom_domain" {
  type        = string
  default     = null
  description = "Custom domain name to associate (e.g. altrx.com). Null = no domain association."
}

variable "sub_domains" {
  type = list(object({
    branch_name = string
    prefix      = string
  }))
  default     = []
  description = "Sub-domain mappings for the custom domain association"
}

variable "environment" {
  type        = string
  description = "Environment tag (staging, preprod, prod)"
}

variable "project" {
  type        = string
  description = "Project tag (ALTRX)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to merge"
}
