terraform {
    required_version = ">= 1.5.0"
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
    backend "s3" {
        bucket       = "<BOOTSTRAPPED_S3_BUCKET_NAME>" # Copy and paste the S3 bucket name from your bootstrap output here!
        key          = "altrx/staging/terraform.tfstate"
        region       = "ap-south-1"
        profile      = "altrx"                         # Using your separate account AWS CLI profile
        use_lockfile = true
        encrypt      = true
    }
}

provider "aws" {
    region  = var.aws_region
    profile = var.aws_profile 
}

# --- Call modules using relative paths to configure ALTRX resources ---
# Example:
# module "vpc" {
#     source   = "../../../../modules/vpc"
#     vpc_cidr = var.vpc_cidr
#     # ...
# }
