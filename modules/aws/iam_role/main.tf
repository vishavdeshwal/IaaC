resource "aws_iam_role" "role" {
  name               = var.name
  assume_role_policy = var.assume_role_policy
  path               = var.path
  description        = var.description

  tags = {
    Name        = var.name
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_iam_role_policy_attachment" "attachment" {
  count      = length(var.policy_arns)
  role       = aws_iam_role.role.name
  policy_arn = var.policy_arns[count.index]
}
