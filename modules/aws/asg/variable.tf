variable "name" {
    type        = string
    description = "Base name for the ASG and Launch Template"
}

variable "ami_id" {
    type        = string
    description = "AMI ID to use in the Launch Template"
}

variable "instance_type" {
    type        = string
    default     = "t3.micro"
    description = "EC2 instance type"
}

variable "subnet_ids" {
    type        = list(string)
    description = "List of subnet IDs the ASG will launch instances in"
}

variable "security_group_ids" {
    type        = list(string)
    description = "Security group IDs to attach to instances"
}

variable "key_name" {
    type        = string
    default     = null
    description = "EC2 key pair name for SSH access. Optional."
}

variable "iam_instance_profile_arn" {
    type        = string
    default     = null
    description = "ARN of the IAM instance profile to attach. Optional. Use the ecs_ec2 module output here for ECS clusters."
}

variable "user_data" {
    type        = string
    default     = null
    description = "Base64-encoded user data script. Optional."
}

variable "min_size" {
    type        = number
    default     = 1
    description = "Minimum number of instances in the ASG"
}

variable "max_size" {
    type        = number
    default     = 3
    description = "Maximum number of instances in the ASG"
}

variable "desired_capacity" {
    type        = number
    default     = 1
    description = "Desired number of instances in the ASG"
}

variable "target_group_arns" {
    type        = list(string)
    default     = []
    description = "List of target group ARNs to register ASG instances with. Empty = no ALB."
}

variable "health_check_type" {
    type        = string
    default     = "EC2"
    description = "Health check type: 'EC2' or 'ELB'"
}

variable "health_check_grace_period" {
    type        = number
    default     = 300
    description = "Seconds after instance launch before health checks begin"
}

variable "root_volume_size" {
    type        = number
    default     = 20
    description = "Root EBS volume size in GiB"
}

variable "root_volume_type" {
    type        = string
    default     = "gp3"
    description = "Root EBS volume type"
}

variable "monitoring" {
    type        = bool
    default     = false
    description = "Enable detailed CloudWatch monitoring on instances"
}

variable "environment" {
    type = string
}

variable "project" {
    type = string
}
