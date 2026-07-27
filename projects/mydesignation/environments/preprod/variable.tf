variable "subscription_id" {
  type        = string
  description = "Azure subscription ID (MYDPremium)."
}

variable "location" {
  type    = string
  default = "southindia"
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}
