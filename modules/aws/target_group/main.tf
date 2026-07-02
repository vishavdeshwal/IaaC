resource "aws_lb_target_group" "tg" {
    name                 = var.use_name_prefix ? null : (var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}-tg")
    port                 = var.port
    protocol             = var.protocol
    target_type          = var.target_type
    vpc_id               = var.vpc_id
    deregistration_delay = var.deregistration_delay

    health_check {
        enabled             = true
        path                = var.health_check_path
        protocol            = var.health_check_protocol
        port                = var.health_check_port
        interval            = var.health_check_interval
        timeout             = var.health_check_timeout
        healthy_threshold   = var.healthy_threshold
        unhealthy_threshold = var.unhealthy_threshold
        matcher             = var.health_check_matcher
    }

    stickiness {
        type            = "lb_cookie"
        cookie_duration = var.stickiness_duration
        enabled         = var.stickiness_enabled
    }

    tags = {
        Name        = "${var.environment}-${var.project}-${var.name}-tg"
        Environment = var.environment
        Project     = var.project
    }

    # Allow new target group to be created before old one is destroyed
    lifecycle {
        create_before_destroy = true
    }
}
