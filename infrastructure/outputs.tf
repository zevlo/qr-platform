output "account_id" {
  value = local.account_id
}

output "region" {
  value = var.region
}

output "qr_bucket_name" {
  value = module.s3.bucket_name
}

output "ecr_repositories" {
  value = {
    api      = try(module.ecr.repository_urls["qr-api"], null)
    frontend = try(module.ecr.repository_urls["qr-frontend"], null)
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_issuer_url" {
  value = module.eks.oidc_issuer_url
}

output "irsa_role_arn" {
  description = "Role ARN the api pod's ServiceAccount must annotate (Phase 4)."
  value       = module.iam_irsa.role_arn
}

output "secrets_manager_secret_arn" {
  value = module.secrets.secret_arn
}

output "secrets_manager_secret_name" {
  value = module.secrets.secret_name
}

output "tfstate_bucket_name" {
  value = module.tfstate.bucket_name
}

output "tfstate_ddb_table" {
  value = module.tfstate.ddb_table
}
