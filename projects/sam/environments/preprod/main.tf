terraform {
    required_version = ">= 1.5.0"
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
    backend "s3" {
        bucket       = "sammmm-terraform-state-847659"
        key          = "sam/preprod/terraform.tfstate" # Isolated state for preprod!
        region       = "ap-south-1"
        profile      = "sam"
        use_lockfile = true
        encrypt      = true
    }
}

provider "aws" {
    region  = var.aws_region
    profile = var.aws_profile 
}

# --- Copy/Paste modules from staging here when promoting infrastructure ---
