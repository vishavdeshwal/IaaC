# -------
# ECR Container Registry Repository
# -------

resource "aws_ecr_repository" "repo" {
    name                 = var.name_override != null ? var.name_override : lower("${var.environment}-${var.project}-${var.name}")
    image_tag_mutability = var.image_tag_mutability

    image_scanning_configuration {
        scan_on_push = var.scan_on_push
    }

    encryption_configuration {
        encryption_type = var.encryption_type
        kms_key         = var.encryption_type == "KMS" ? var.kms_key : null
    }

    tags = {
        Name        = "${var.environment}-${var.project}-${var.name}"
        Environment = var.environment
        Project     = var.project
    }
}


# -------
# ECR Lifecycle Policy (Automatically clean up old/untagged images)
# -------

resource "aws_ecr_lifecycle_policy" "policy" {
    count = var.lifecycle_policy_enabled ? 1 : 0

    repository = aws_ecr_repository.repo.name

    policy = jsonencode({
        rules = [
            {
                rulePriority = 1
                description  = "Expire untagged images older than 14 days"
                selection = {
                    tagStatus   = "untagged"
                    countType   = "sinceImagePushed"
                    countUnit   = "days"
                    countNumber = 14
                }
                action = {
                    type = "expire"
                }
            },
            {
                rulePriority = 2
                description  = "Keep only the last ${var.max_image_count} images"
                selection = {
                    tagStatus   = "any"
                    countType   = "imageCountMoreThan"
                    countNumber = var.max_image_count
                }
                action = {
                    type = "expire"
                }
            }
        ]
    })
}
