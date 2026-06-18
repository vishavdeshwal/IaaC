variable "public_subnet_ids" {
    type = map(string)
}

variable "private_subnet_ids" {
    type = map(string)
}

variable "public_route_table_id" {
    type = string
}

variable "private_route_table_id" {
    type = string
}

