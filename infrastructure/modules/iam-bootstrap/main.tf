locals {
  oidc_arn = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
  oidc_url = "https://token.actions.githubusercontent.com"
}

# Pre-existing OIDC IdP. Imported, not created.
resource "aws_iam_openid_connect_provider" "github" {
  url             = local.oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  # Sentinel thumbprint — AWS maintains the real list server-side.
  thumbprint_list = ["0000000000000000000000000000000000000000"]
}

# Pre-existing role, created by bootstrap/aws.sh. Imported, not created.
resource "aws_iam_role" "gha" {
  name        = var.role_name
  description = "GitHub Actions OIDC role for ${var.github_org}/${var.github_repo}."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Accept both the textbook name format and GitHub's v2 ID format.
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_org}/${var.github_repo}:*",
              "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:*"
            ]
          }
        }
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

# Inline policy mirroring what bootstrap/aws.sh applied.
resource "aws_iam_role_policy" "ecr_push" {
  name = "ecr-push"
  role = aws_iam_role.gha.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          "arn:aws:ecr:${var.region}:${var.account_id}:repository/qr-api",
          "arn:aws:ecr:${var.region}:${var.account_id}:repository/qr-frontend"
        ]
      }
    ]
  })
}
