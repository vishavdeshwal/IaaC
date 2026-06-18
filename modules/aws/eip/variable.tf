variable "environment" {
    type = string
}

variable "project" {
    type = string
}

variable "name" {
    type    = string
    default = "nat-eip"
}

variable "name_override" {
    type    = string
    default = null
}

variable "instance_id" {
    type    = string
    default = null
}