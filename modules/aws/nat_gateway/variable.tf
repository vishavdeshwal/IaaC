variable "eip_allocation_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "igw_dependency" {
  type = string
}

variable "availability_mode" {
  type        = string
  default     = "subnet"
  description = "NAT Gateway availability mode ('subnet' or 'regional')"
}

variable "name_override" {
  type        = string
  default     = null
  description = "Optional name override for NAT Gateway"
}

