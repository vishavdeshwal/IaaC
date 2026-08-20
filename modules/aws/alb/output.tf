output "alb_id" {
  value       = aws_lb.alb.id
  description = "ID of the ALB"
}

output "alb_arn" {
  value       = aws_lb.alb.arn
  description = "ARN of the ALB"
}

output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "DNS name of the ALB — use this as your CNAME target"
}

output "alb_zone_id" {
  value       = aws_lb.alb.zone_id
  description = "Hosted zone ID of the ALB — use this for Route53 alias records"
}

output "http_listener_arn" {
  value       = aws_lb_listener.http.arn
  description = "ARN of the HTTP listener"
}

output "https_listener_arn" {
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
  description = "ARN of the HTTPS listener (null if no certificate was provided)"
}

output "alb_arn_suffix" {
  value       = aws_lb.alb.arn_suffix
  description = "ARN suffix of the ALB for use in CloudWatch metrics"
}

