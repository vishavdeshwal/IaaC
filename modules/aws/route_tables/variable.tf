variable "vpc_id" {
  type = string
}

variable "igw_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "nat_gateway_id" {
  type = string
}

variable "public_subnet_ids" {
  type        = map(string)
  description = "Map of public subnet IDs"
  default     = {}
}

variable "private_subnet_ids" {
  type        = map(string)
  description = "Map of private subnet IDs"
  default     = {}
}
