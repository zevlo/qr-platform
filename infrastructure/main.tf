data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)
  name       = var.project

  common_tags = {
    Project     = var.project
    ManagedBy   = "terraform"
    Environment = var.environment
  }
}

# ------------------------------------------------------------
# Pre-existing resources (adopted via terraform import)
# ------------------------------------------------------------
module "tfstate" {
  source = "./modules/tfstate"

  bucket_name = var.tfstate_bucket_name
  ddb_table   = var.tfstate_ddb_table
  tags        = local.common_tags
}

module "s3" {
  source      = "./modules/s3"
  bucket_name = var.qr_bucket_name
  tags        = local.common_tags
}

module "ecr" {
  source   = "./modules/ecr"
  region   = var.region
  repos    = ["qr-api", "qr-frontend"]
  tags     = local.common_tags
}

module "iam_bootstrap" {
  source          = "./modules/iam-bootstrap"
  region          = var.region
  account_id      = local.account_id
  github_org      = "zevlo"
  github_repo     = "qr-platform"
  github_owner_id = "104938351"
  github_repo_id  = "1307854556"
  role_name       = "qr-platform-gha"
  tags            = local.common_tags
}

# ------------------------------------------------------------
# New infrastructure (created by terraform apply)
# ------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  name           = local.name
  region         = var.region
  cidr           = "10.0.0.0/16"
  azs            = local.azs
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  # Private subnets exist for future expansion; nodes live in public subnets
  # because we're not provisioning a NAT gateway (cost discipline).
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  tags            = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  name              = local.name
  kubernetes_version = var.cluster_version
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
  node_count        = var.node_count
  tags              = local.common_tags
}

# IRSA: lets the api pod in cluster write to the QR bucket.
# Phase 4 must annotate the api ServiceAccount with the returned role ARN.
module "iam_irsa" {
  source = "./modules/iam-irsa"

  name             = "${local.name}-api"
  namespace        = "qr-app"
  service_account  = "api"
  account_id       = local.account_id
  oidc_issuer_url  = module.eks.oidc_issuer_url
  policy_arns      = {
    s3 = module.s3.write_policy_arn
  }
  tags = local.common_tags
}

module "secrets" {
  source = "./modules/secrets-manager"

  name        = "${local.name}/api"
  description = "Non-secret runtime config for the api pod (bucket + region)."
  data = {
    BUCKET_NAME = var.qr_bucket_name
    AWS_REGION  = var.region
  }
  tags = local.common_tags
}
