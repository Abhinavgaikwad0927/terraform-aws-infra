output "repository_name" {
  description = "ECR Repository Name"
  value       = aws_ecr_repository.this.name
}

output "repository_url" {
  description = "ECR Repository URL"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ECR Repository ARN"
  value       = aws_ecr_repository.this.arn
}

output "registry_id" {
  description = "AWS Account Registry ID"
  value       = aws_ecr_repository.this.registry_id
}
