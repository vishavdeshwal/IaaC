variable "subscription_id" {
  type        = string
  description = "Azure subscription ID (MYDPremium)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that will hold the tfstate storage account."
}

variable "location" {
  type        = string
  default     = "southindia"
  description = "Azure region for the state storage account."
}

variable "project" {
  type        = string
  default     = "mydesignation"
  description = "Project name prefix applied to the state storage account and tags."
}
