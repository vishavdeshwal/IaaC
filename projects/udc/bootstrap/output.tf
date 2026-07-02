output "s3_bucket_name" {
  value       = aws_s3_bucket.state.id
  description = "The name of bootstrapped S3 bucket for storing remote state"
}   