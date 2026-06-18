variable "vpc_id" {
    type = string
}

variable "name" {
    type = string
}

variable "ingress_rules" {
    type = list(object({
        from_port = number
        to_port = number
        protocol = string
        # Making them optional as SG might need cidr or sg or both
        cidr_blocks = optional(list(string), [])
        security_groups = optional(list(string), [])
        description = string
    }))
}

variable "egress_rules" {
    type = list(object({
        from_port = number
        to_port = number
        protocol = string
        cidr_blocks = optional(list(string), [])
        security_groups = optional(list(string), [])
        description = string
    }))
}

variable "environment" {
    type = string
}

variable "project" {
    type = string
}

variable "name_override" {
    type    = string
    default = null
}

variable "description" {
    type    = string
    default = null
}