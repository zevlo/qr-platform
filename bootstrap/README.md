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
| IAM role | `qr-platform-gha` | Trusts `repo:zevlo/qr-platform:*` |
| Inline policy | `ecr-push` on the role | Push permissions scoped to the two repos |

## Phase 3 handoff — `terraform import` addresses

When the ECR and IAM modules land in Phase 3, import (don't recreate) these resources so Terraform adopts them without state drift:

```
terraform import module.ecr.aws_ecr_repository.api    746669194590.dkr.ecr.us-east-1.amazonaws.com/qr-api
terraform import module.ecr.aws_ecr_repository.frontend 746669194590.dkr.ecr.us-east-1.amazonaws.com/qr-frontend
terraform import module.iam.aws_iam_role.gha          qr-platform-gha
terraform import module.iam.aws_iam_openid_connect_provider.github arn:aws:iam::746669194590:oidc-provider/token.actions.githubusercontent.com
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
