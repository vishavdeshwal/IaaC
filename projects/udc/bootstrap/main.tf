terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# It generates a random integer for s3 bucket to make it global unique
resource "random_integer" "suffix" {
  min = 100000
  max = 999999
}

resource "aws_s3_bucket" "state" {
  bucket = "${lower(var.project)}-terraform-state-${random_integer.suffix.result}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project}-bootstrap-tfstate-bucket"
    Environment = "bootstrap"
    Project     = var.project
  }
}

#Enable versioning
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

#Enable SSE (server-side-encryption)
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#Block all public access to state bucket
resource "aws_s3_bucket_public_access_block" "state_public_block" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


#Object ownership
resource "aws_s3_bucket_ownership_controls" "state_ownership" {
    bucket = aws_s3_bucket.state.id

    rule {
        object_ownership = "BucketOwnerPreferred"
    }
}


