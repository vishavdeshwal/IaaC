aws_region  = "eu-west-1"
aws_profile = "bsl"
environment = "staging"
project     = "bsl"

vpc_cidr        = "10.1.0.0/16"
public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnets = ["10.1.10.0/24", "10.1.11.0/24"]
