# -------
# SQS Event Source Mapping
# -------

resource "aws_lambda_event_source_mapping" "sqs" {
  count = var.sqs_trigger_enabled ? 1 : 0

  event_source_arn                   = var.sqs_queue_arn
  function_name                      = var.function_arn
  batch_size                         = var.sqs_batch_size
  maximum_batching_window_in_seconds = var.sqs_maximum_batching_window
  enabled                            = true
}


# -------
# EventBridge Schedule Trigger
# -------

resource "aws_cloudwatch_event_rule" "schedule" {
  count = var.schedule_trigger_enabled ? 1 : 0

  name                = "${var.environment}-${var.project}-${var.function_name}-schedule"
  description         = var.schedule_description
  schedule_expression = var.schedule_expression

  tags = {
    Name        = "${var.environment}-${var.project}-${var.function_name}-schedule"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_cloudwatch_event_target" "schedule" {
  count = var.schedule_trigger_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.schedule[0].name
  target_id = "${var.function_name}-target"
  arn       = var.function_arn
}

resource "aws_lambda_permission" "schedule" {
  count = var.schedule_trigger_enabled ? 1 : 0

  statement_id  = "AllowEventBridgeSchedule"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule[0].arn
}


# -------
# S3 Trigger
# -------

resource "aws_lambda_permission" "s3" {
  count = var.s3_trigger_enabled ? 1 : 0

  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.s3_bucket_id}"
}

resource "aws_s3_bucket_notification" "s3" {
  count  = var.s3_trigger_enabled ? 1 : 0
  bucket = var.s3_bucket_id

  lambda_function {
    lambda_function_arn = var.function_arn
    events              = var.s3_events
    filter_prefix       = var.s3_filter_prefix
    filter_suffix       = var.s3_filter_suffix
  }

  depends_on = [aws_lambda_permission.s3]
}
