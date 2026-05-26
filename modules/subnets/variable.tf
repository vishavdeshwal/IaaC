variable "public_subnets" {
    type = map(object({
        cidr = string
        az_index = number
    }))
}

variable "vpc_id" {
    type = string
}

variable "private_subnets" {
    type = map(object({
        cidr = string
        az_index = number
    }))
}

variable "environment" {
    type = string
}

variable "project" {
    type = string
}