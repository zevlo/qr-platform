output "repository_ids" {
  value = { for k, v in aws_ecr_repository.this : k => v.registry_id }
}

output "repository_urls" {
  value = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  value = { for k, v in aws_ecr_repository.this : k => v.arn }
}
