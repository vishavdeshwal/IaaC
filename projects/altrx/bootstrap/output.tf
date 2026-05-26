output "s3_bucket_name" {
  value       = aws_s3_bucket.state.id
  description = "The name of the bootstrapped S3 bucket for storing remote state for ALTRX. Copy this into your environment backend blocks!"
}
