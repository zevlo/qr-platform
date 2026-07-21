# Bootstrap — one-time AWS resources for Phase 2 CI/CD

This creates the ECR repos, the GitHub OIDC identity provider, and the IAM role GitHub Actions assumes. Phase 3's Terraform will **adopt** (not recreate) these resources via `terraform import`.

## Run

```bash
AWS_PROFILE=admin-zach ./bootstrap/aws.sh
```

Idempotent: each step guards on the resource already existing, so re-runs are safe.

## After running

Set two GitHub Actions **variables** (not secrets — OIDC trust is the auth):

```bash
gh variable set AWS_ROLE_ARN --body "arn:aws:iam::746669194590:role/qr-platform-gha"
gh variable set AWS_REGION   --body "us-east-1"
```

No `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets should ever be set on this repo.

## What gets created

| Resource | Name | Purpose |
|---|---|---|
| ECR repo | `qr-api` | Backend image registry, scan-on-push |
| ECR repo | `qr-frontend` | Frontend image registry, scan-on-push |
| ECR lifecycle policy | both repos | Untagged expire after 1d; keep last 10 tagged |
| OIDC IdP | `token.actions.githubusercontent.com` | Lets GitHub Actions mint AWS tokens |
| IAM role | `qr-platform-gha` | Trusts both `sub` formats from `repo:zevlo/qr-platform` |
| Inline policy | `ecr-push` on the role | Push permissions scoped to the two repos |
| S3 bucket | `zevlo-qr-platform-tfstate` | Terraform state (versioned, SSE, public-blocked, 90d noncurrent lifecycle) |
| DynamoDB table | `terraform-locks` | State locking (PAY_PER_REQUEST) |

> **OIDC `sub` quirk:** This repo's Actions tokens use GitHub's v2 ID-format subject claim (`repo:zevlo@104938351/qr-platform@1307854556:ref:...`) rather than the textbook name format. The role trust policy accepts **both** formats so the trust still works if GitHub flips the default back.

## Phase 3 handoff — `terraform import` addresses

When the ECR and IAM modules land in Phase 3, import (don't recreate) these resources so Terraform adopts them without state drift:

```
terraform import module.s3.aws_s3_bucket.qr_codes                  zevlo-qr-platform-codes
terraform import module.ecr.aws_ecr_repository.this["qr-api"]      qr-api
terraform import module.ecr.aws_ecr_repository.this["qr-frontend"] qr-frontend
terraform import module.iam_bootstrap.aws_iam_role.gha             qr-platform-gha
terraform import module.iam_bootstrap.aws_iam_openid_connect_provider.github arn:aws:iam::746669194590:oidc-provider/token.actions.githubusercontent.com
terraform import module.tfstate.aws_s3_bucket.this                 zevlo-qr-platform-tfstate
terraform import module.tfstate.aws_dynamodb_table.locks           terraform-locks
```

## Tear down

When the capstone is over and you don't need CI to push anymore:

```bash
aws iam delete-role-policy --role-name qr-platform-gha --policy-name ecr-push
aws iam delete-role --role-name qr-platform-gha
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::746669194590:oidc-provider/token.actions.githubusercontent.com
aws ecr delete-repository --repository-name qr-api --force
aws ecr delete-repository --repository-name qr-frontend --force
```
