variable "name" {
  type    = string
  default = "app"
}

variable "name_override" {
  type    = string
  default = null
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "ip_configuration_name" {
  type        = string
  default     = "ipconfig1"
  description = "Name of the IP configuration block."
}

variable "subnet_id" {
  type = string
}

variable "private_ip_address_allocation" {
  type        = string
  default     = "Dynamic"
  description = "Dynamic or Static."
}

variable "private_ip_address" {
  type        = string
  default     = null
  description = "Required only when allocation is Static."
}

variable "public_ip_address_id" {
  type        = string
  default     = null
  description = "Public IP resource ID to attach, or null for none."
}

variable "network_security_group_id" {
  type        = string
  default     = null
  description = "NSG to associate at the NIC level, or null for none."
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
