terraform {
    required_version = ">= 1.5.0"
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
    backend "s3" {
        bucket       = "altrx-terraform-state-993197"
        key          = "altrx/preprod/terraform.tfstate"
        region       = "us-east-1"
        profile      = "altrx"
        use_lockfile = true
        encrypt      = true
    }
}

provider "aws" {
    region  = var.aws_region
    profile = var.aws_profile 
}

# --- Paste your import blocks or modules here ---
