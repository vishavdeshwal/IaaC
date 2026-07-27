variable "name" {
  type    = string
  default = "storage"
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

variable "account_tier" {
  type    = string
  default = "Standard"
}

variable "account_replication_type" {
  type        = string
  default     = "LRS"
  description = "LRS, GRS, RAGRS, ZRS, etc."
}

variable "account_kind" {
  type    = string
  default = "StorageV2"
}

variable "access_tier" {
  type    = string
  default = "Hot"
}

variable "https_traffic_only_enabled" {
  type    = bool
  default = true
}

variable "min_tls_version" {
  type    = string
  default = "TLS1_2"
}

variable "allow_nested_items_to_be_public" {
  type        = bool
  default     = false
  description = "Allow public (anonymous) access to blobs/containers. Set true only if a container needs public 'blob' access."
}

variable "containers" {
  type = map(object({
    access_type = string # private | blob | container
  }))
  default     = {}
  description = "Map of container name => { access_type }."
}

variable "queues" {
  type        = list(string)
  default     = []
  description = "Storage queue names to create in this account."
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
