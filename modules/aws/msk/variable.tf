variable "cluster_name" {
  type        = string
  description = "The name of the MSK cluster"
}

variable "kafka_version" {
  type        = string
  default     = "3.6.0"
  description = "Apache Kafka version"
}

variable "number_of_nodes" {
  type        = number
  default     = 2
  description = "Number of broker nodes"
}

variable "instance_type" {
  type        = string
  default     = "kafka.t3.small"
  description = "Broker instance type"
}

variable "ebs_volume_size" {
  type        = number
  default     = 20
  description = "EBS storage volume size in GB per broker node"
}

variable "client_subnets" {
  type        = list(string)
  description = "Subnets for MSK broker nodes"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups attached to MSK brokers"
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}
