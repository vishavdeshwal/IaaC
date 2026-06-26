resource "aws_iam_policy" "policy" {
  count       = var.is_inline ? 0 : 1
  name        = var.name
  description = var.description
  policy      = var.policy

  tags = {
    Name        = var.name
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_iam_role_policy_attachment" "attachment" {
  count      = (!var.is_inline && var.role_name != null) ? 1 : 0
  role       = var.role_name
  policy_arn = aws_iam_policy.policy[0].arn
}

resource "aws_iam_role_policy" "inline_policy" {
  count  = (var.is_inline && var.role_name != null) ? 1 : 0
  name   = var.name
  role   = var.role_name
  policy = var.policy
}

resource "aws_iam_user_policy" "inline_user_policy" {
  count  = (var.is_inline && var.user_name != null) ? 1 : 0
  name   = var.name
  user   = var.user_name
  policy = var.policy
}

resource "aws_iam_user_policy_attachment" "user_attachment" {
  count      = (!var.is_inline && var.user_name != null) ? 1 : 0
  user       = var.user_name
  policy_arn = aws_iam_policy.policy[0].arn
}

