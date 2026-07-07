variable "name" {
  type        = string
  description = "Logical name for this EC2 instance"
}

variable "ami_id" {
  type        = string
  description = "AMI ID to launch (e.g. 'ami-0c55b159cbfafe1f0')"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the instance will be launched"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs to attach"
}

variable "key_name" {
  type        = string
  default     = null
  description = "Name of the EC2 key pair for SSH. Optional."
}

variable "iam_instance_profile" {
  type        = string
  default     = null
  description = "Name or ARN of the IAM instance profile to attach. Optional."
}

variable "user_data" {
  type        = string
  default     = null
  description = "User data script (base64-encoded or plain text). Optional."
}

variable "associate_public_ip" {
  type        = bool
  default     = false
  description = "Whether to assign a public IP to the instance"
}

variable "root_volume_size" {
  type        = number
  default     = 20
  description = "Root EBS volume size in GiB"
}

variable "root_volume_type" {
  type        = string
  default     = "gp3"
  description = "Root EBS volume type (gp2, gp3, io1, etc.)"
}

variable "disable_api_termination" {
  type        = bool
  default     = false
  description = "Whether to protect the instance from accidental termination"
}

variable "monitoring" {
  type        = bool
  default     = false
  description = "Whether to enable detailed CloudWatch monitoring"
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "root_volume_encrypted" {
  type        = bool
  default     = true
  description = "Whether to encrypt the root block device"
}

variable "name_override" {
  type        = string
  default     = null
  description = "Override the default Name tag"
}
