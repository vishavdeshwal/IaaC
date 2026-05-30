output "carevalidate_errors_spike_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.carevalidate_errors_spike.arn
  description = "The ARN of the CareValidate errors spike alarm"
}

output "paid_no_case_any_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.paid_no_case_any.arn
  description = "The ARN of the Paid But No Case alarm"
}
