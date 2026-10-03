output "cloudfront_distribution_arn" {
  value       = aws_cloudfront_distribution.this.arn
  description = "The ARN of the CloudFront distribution"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.this.domain_name
  description = "The domain name of the CloudFront distribution"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.this.id
  description = "The ID of the CloudFront distribution"
}

output "cloudfront_hosted_zone_id" {
  value       = aws_cloudfront_distribution.this.hosted_zone_id
  description = "The CloudFront Route 53 Zone ID"
}
