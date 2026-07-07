resource "aws_amplify_app" "app" {
  name                        = var.name
  repository                  = var.repository
  platform                    = var.platform
  iam_service_role_arn        = var.iam_service_role_arn
  build_spec                  = var.build_spec
  environment_variables       = var.environment_variables
  enable_branch_auto_build    = var.enable_branch_auto_build
  enable_branch_auto_deletion = var.enable_branch_auto_deletion
  enable_basic_auth           = false

  dynamic "custom_rule" {
    for_each = var.custom_rules
    content {
      source    = custom_rule.value.source
      target    = custom_rule.value.target
      status    = custom_rule.value.status
      condition = lookup(custom_rule.value, "condition", null)
    }
  }

  cache_config {
    type = var.cache_config_type
  }

  tags = merge({
    Name        = var.name
    Environment = var.environment
    Project     = var.project
  }, var.tags)
}

resource "aws_amplify_branch" "branches" {
  for_each = var.branches

  app_id      = aws_amplify_app.app.id
  branch_name = each.key
  stage       = each.value.stage

  enable_auto_build           = lookup(each.value, "enable_auto_build", true)
  enable_pull_request_preview = lookup(each.value, "enable_pull_request_preview", false)

  environment_variables = lookup(each.value, "environment_variables", {})

  lifecycle {
    ignore_changes = [environment_variables]
  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_amplify_domain_association" "domain" {
  count = var.custom_domain != null ? 1 : 0

  app_id      = aws_amplify_app.app.id
  domain_name = var.custom_domain

  dynamic "sub_domain" {
    for_each = var.sub_domains
    content {
      branch_name = sub_domain.value.branch_name
      prefix      = sub_domain.value.prefix
    }
  }
}
