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

# Generate a random integer to guarantee S3 bucket global uniqueness in the second account
resource "random_integer" "suffix" {
  min = 100000
  max = 999999
}

# The S3 bucket to store all altrx environment state files
resource "aws_s3_bucket" "state" {
  bucket = "${lower(var.project)}-terraform-state-${random_integer.suffix.result}"

  # Protect the state bucket from accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project}-bootstrap-tfstate-bucket"
    Environment = "bootstrap"
    Project     = var.project
  }
}

# Enable versioning so we have full backup history of all state changes
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption by default using S3 Managed Keys (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Explicitly block all public access to the state bucket (essential security)
resource "aws_s3_bucket_public_access_block" "state_public_block" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Object ownership controls
resource "aws_s3_bucket_ownership_controls" "state_ownership" {
  bucket = aws_s3_bucket.state.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
