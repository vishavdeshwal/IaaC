output "repository_arn" {
    value       = aws_ecr_repository.repo.arn
    description = "The ARN of the repository"
}

output "repository_url" {
    value       = aws_ecr_repository.repo.repository_url
    description = "The URL of the repository (used for docker push / pull)"
}

output "repository_name" {
    value       = aws_ecr_repository.repo.name
    description = "The name of the repository"
}

output "registry_id" {
    value       = aws_ecr_repository.repo.registry_id
    description = "The registry ID where the repository was created"
}
