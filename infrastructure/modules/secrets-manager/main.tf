# Holds non-secret runtime config for the api pod (bucket name, region).
# Real AWS auth is handled by IRSA — no credentials in this secret.
# Phase 5 (External Secrets Operator) will sync this into the cluster.

resource "aws_secretsmanager_secret" "this" {
  name        = var.name
  description = var.description
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode(var.data)
}
