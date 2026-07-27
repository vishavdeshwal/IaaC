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

variable "public_key" {
  type        = string
  description = "OpenSSH-formatted public key material (ssh-rsa AAAA...)."
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
