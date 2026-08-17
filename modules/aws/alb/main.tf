# -------
# Application Load Balancer
# -------

resource "aws_lb" "alb" {
  name               = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout
  enable_http2               = var.enable_http2

  dynamic "access_logs" {
    # for_each = <CONDITION> ? <IF_TRUE> : <IF_FALSE>
    for_each = var.access_logs_bucket != null ? [1] : []
    content {
      bucket = var.access_logs_bucket
      # null keeps the historical computed prefix; set "" for a bucket root.
      prefix  = var.access_logs_prefix != null ? var.access_logs_prefix : "${var.environment}-${var.project}-${var.name}"
      enabled = true
    }
  }

  tags = {
    Name        = "${var.environment}-${var.project}-${var.name}-alb"
    Environment = var.environment
    Project     = var.project
  }
}


# -------
# HTTP Listener
# -------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = var.http_port
  protocol          = var.http_protocol
  certificate_arn   = var.http_certificate_arn
  ssl_policy        = var.http_protocol == "HTTPS" ? var.ssl_policy : null

  dynamic "default_action" {
    for_each = var.http_default_action == "redirect_to_https" ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = tostring(var.https_port)
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.http_default_action == "forward" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = var.http_target_group_arn
    }
  }

  tags = {
    Name        = "${var.environment}-${var.project}-${var.name}-http-listener"
    Environment = var.environment
    Project     = var.project
  }
}


# -------
# HTTPS Listener (only if certificate_arn is provided)
# -------

resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.alb.arn
  port              = var.https_port
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = var.https_target_group_arn
  }

  tags = {
    Name        = "${var.environment}-${var.project}-${var.name}-https-listener"
    Environment = var.environment
    Project     = var.project
  }
}
