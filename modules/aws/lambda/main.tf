# -------
# IAM Execution Role
# -------

resource "aws_iam_role" "lambda" {
    name = var.role_name_override != null ? var.role_name_override : "${var.environment}-${var.project}-${var.function_name}-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action    = "sts:AssumeRole"
            Effect    = "Allow"
            Principal = {
                Service = "lambda.amazonaws.com"
            }
        }]
    })

    tags = {
        Name        = var.role_name_override != null ? var.role_name_override : "${var.environment}-${var.project}-${var.function_name}-role"
        Environment = var.environment
        Project     = var.project
    }
}

# Basic execution policy (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "basic_execution" {
    role       = aws_iam_role.lambda.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access policy (attached only if subnet_ids are provided)
resource "aws_iam_role_policy_attachment" "vpc_access" {
    count      = length(var.subnet_ids) > 0 ? 1 : 0
    role       = aws_iam_role.lambda.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Additional policies provided by the caller
resource "aws_iam_role_policy_attachment" "additional" {
    count      = length(var.additional_policy_arns)
    role       = aws_iam_role.lambda.name
    policy_arn = var.additional_policy_arns[count.index]
}


# -------
# Lambda Function
# -------

resource "aws_lambda_function" "lambda" {
    function_name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.function_name}"
    role          = aws_iam_role.lambda.arn
    runtime       = var.image_uri == null ? var.runtime : null
    handler       = var.image_uri == null ? var.handler : null
    package_type  = var.image_uri != null ? "Image" : "Zip"

    # Deployment package — exactly one of these should be set
    filename         = var.filename
    s3_bucket        = var.s3_bucket
    s3_key           = var.s3_key
    image_uri        = var.image_uri
    source_code_hash = var.source_code_hash

    memory_size                    = var.memory_size
    timeout                        = var.timeout
    reserved_concurrent_executions = var.reserved_concurrent_executions

    layers = var.layers

    dynamic "environment" {
        for_each = length(var.environment_variables) > 0 ? [1] : []
        content {
            variables = var.environment_variables
        }
    }

    dynamic "vpc_config" {
        for_each = length(var.subnet_ids) > 0 ? [1] : []
        content {
            subnet_ids         = var.subnet_ids
            security_group_ids = var.security_group_ids
        }
    }

    tags = {
        Name        = "${var.environment}-${var.project}-${var.function_name}"
        Environment = var.environment
        Project     = var.project
    }

    depends_on = [
        aws_iam_role_policy_attachment.basic_execution,
        aws_iam_role_policy_attachment.vpc_access,
    ]
}

# ECR Repository Policy allowing Lambda service access (created if ecr_repository_name is provided)
resource "aws_ecr_repository_policy" "lambda_ecr_policy" {
    count      = var.ecr_repository_name != null ? 1 : 0
    repository = var.ecr_repository_name

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Sid    = "LambdaECRImageRetrievalPolicy"
            Effect = "Allow"
            Principal = {
                Service = "lambda.amazonaws.com"
            }
            Action = [
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchCheckLayerAvailability"
            ]
        }]
    })
}

# Attach ECR Read permissions to the Lambda Execution Role
resource "aws_iam_role_policy" "lambda_ecr_execution_policy" {
    count = var.ecr_repository_arn != null ? 1 : 0
    name  = "${var.environment}-${var.project}-${var.function_name}-ecr-policy"
    role  = aws_iam_role.lambda.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = [
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchCheckLayerAvailability"
            ]
            Resource = var.ecr_repository_arn
        }]
    })
}
