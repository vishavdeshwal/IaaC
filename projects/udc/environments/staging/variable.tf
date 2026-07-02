variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
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

# --- Container Definitions ---

variable "container_def_be" {
  type        = string
  description = "JSON string defining the backend container"
}

variable "container_def_truedesk" {
  type        = string
  description = "JSON string defining the truedesk container"
}

variable "container_def_master_web" {
  type        = string
  description = "JSON string defining the master-web container"
}

variable "container_def_master_admin" {
  type        = string
  description = "JSON string defining the master-admin container"
}

variable "container_def_student_web" {
  type        = string
  description = "JSON string defining the student-web container"
}

variable "container_def_instructor_web" {
  type        = string
  description = "JSON string defining the instructor-web container"
}
