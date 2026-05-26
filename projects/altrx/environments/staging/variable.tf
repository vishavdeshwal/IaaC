variable "aws_region" {
    type    = string
    default = "ap-south-1"
}

variable "aws_profile" {
    type    = string
    default = "altrx"
}

variable "environment" {
    type    = string
    default = "staging"
}

variable "project" {
    type    = string
    default = "ALTRX"
}

variable "vpc_cidr" {
    type    = string
    default = "10.1.0.0/16" # Different subnet range than SAM to avoid conflicts
}
