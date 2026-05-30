# =============================================================
# CloudWatch Log Metric Filters
# =============================================================

resource "aws_cloudwatch_log_metric_filter" "ext_call_errors" {
  name           = "${var.environment}-ext-call-errors"
  pattern        = "{ $.evt = \"ext_call\" && $.outcome = \"error\" }"
  log_group_name = var.log_group_name

  metric_transformation {
    name          = "ExtCallErrors"
    namespace     = "${var.project}/API"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "carevalidate_errors" {
  name           = "${var.environment}-carevalidate-errors"
  pattern        = "{ $.evt = \"ext_call\" && $.client = \"carevalidate\" && $.outcome = \"error\" }"
  log_group_name = var.log_group_name

  metric_transformation {
    name          = "CareValidateErrors"
    namespace     = "${var.project}/API"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "paid_no_case" {
  name           = "${var.environment}-paid-no-case"
  pattern        = "{ $.evt = \"client_log\" && $.event = \"case_submit_no_caseid\" }"
  log_group_name = var.log_group_name

  metric_transformation {
    name          = "PaidButNoCase"
    namespace     = "${var.project}/API"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "carevalidate_5xx" {
  name           = "${var.environment}-carevalidate-5xx"
  pattern        = "{ $.evt = \"ext_call\" && $.client = \"carevalidate\" && $.status >= 500 }"
  log_group_name = var.log_group_name

  metric_transformation {
    name          = "CareValidate5xx"
    namespace     = "${var.project}/API"
    value         = "1"
    default_value = "0"
  }
}

# =============================================================
# CloudWatch Metric Alarms (Static & Anomaly Detection)
# =============================================================

# Static spike alarm for CareValidate Errors (>= 5 in 5 minutes)
resource "aws_cloudwatch_metric_alarm" "carevalidate_errors_spike" {
  alarm_name          = "${var.environment}-carevalidate-errors-spike"
  alarm_description   = "CareValidate API errors >= 5 in 5min"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CareValidateErrors"
  namespace           = "${var.project}/API"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]

  tags = merge({
    Name        = "${var.environment}-carevalidate-errors-spike"
    Environment = var.environment
  }, var.tags)
}

# Static alarm for CareValidate 5xx (>= 3 in 5 minutes)
resource "aws_cloudwatch_metric_alarm" "carevalidate_5xx" {
  alarm_name          = "${var.environment}-carevalidate-5xx"
  alarm_description   = "CareValidate server-side 5xx errors >= 3 in 5min"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CareValidate5xx"
  namespace           = "${var.project}/API"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]

  tags = merge({
    Name        = "${var.environment}-carevalidate-5xx"
    Environment = var.environment
  }, var.tags)
}

# Static alarm for "Paid but no case" silent failure (>= 1 in 5 minutes)
resource "aws_cloudwatch_metric_alarm" "paid_no_case_any" {
  alarm_name          = "${var.environment}-paid-no-case-any"
  alarm_description   = "At least one paid-but-no-case silent failure occurred"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "PaidButNoCase"
  namespace           = "${var.project}/API"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]

  tags = merge({
    Name        = "${var.environment}-paid-no-case-any"
    Environment = var.environment
  }, var.tags)
}

# Anomaly detection alarm for CareValidate Errors (expected band 2 stddev)
resource "aws_cloudwatch_metric_alarm" "carevalidate_errors_anomaly" {
  alarm_name          = "${var.environment}-carevalidate-errors-anomaly"
  alarm_description   = "CareValidate errors above expected band"
  comparison_operator = "GreaterThanUpperThreshold"
  evaluation_periods  = 2
  threshold_metric_id = "ad1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]

  metric_query {
    id          = "m1"
    return_data = true

    metric {
      metric_name = "CareValidateErrors"
      namespace   = "${var.project}/API"
      period      = 300
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "ad1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
    label       = "Expected band (2 stddev)"
    return_data = true
  }

  tags = merge({
    Name        = "${var.environment}-carevalidate-errors-anomaly"
    Environment = var.environment
  }, var.tags)
}
