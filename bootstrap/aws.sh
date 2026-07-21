#!/usr/bin/env bash
# Bootstrap AWS resources for qr-platform.
#   - Phase 2: ECR + OIDC + IAM role for GitHub Actions
#   - Phase 3: Terraform state backend (S3 + DynamoDB lock table)
#
# Run once from a laptop authenticated as an admin (e.g. `admin-zach`).
# Idempotent: each step guards on the resource already existing.
#
#   AWS_PROFILE=admin-zach ./bootstrap/aws.sh
#
# After it completes, set these GitHub Actions variables (NOT secrets):
#   gh variable set AWS_ROLE_ARN --body "<printed role ARN>"
#   gh variable set AWS_REGION   --body "us-east-1"
set -euo pipefail

REGION="us-east-1"
ACCOUNT_ID="746669194590"
GITHUB_ORG="zevlo"
GITHUB_REPO="qr-platform"
GITHUB_OWNER_ID="104938351"
GITHUB_REPO_ID="1307854556"
ROLE_NAME="qr-platform-gha"
OIDC_URL="https://token.actions.githubusercontent.com"
# AWS manages the actual thumbprint list; the sentinel below tells IAM to use it.
OIDC_THUMBPRINT="0000000000000000000000000000000000000000"

TFSTATE_BUCKET="zevlo-qr-platform-tfstate"
TFSTATE_DDB_TABLE="terraform-locks"

REPOS=("qr-api" "qr-frontend")

echo "==> Region: ${REGION}    Account: ${ACCOUNT_ID}"
echo "==> Repo:    ${GITHUB_ORG}/${GITHUB_REPO}"
echo

# ------------------------------------------------------------
# 1. ECR repos + scan-on-push + lifecycle policy
# ------------------------------------------------------------
LIFECYCLE_POLICY=$(cat <<'JSON'
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images after 1 day",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "Keep last 10 tagged images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": { "type": "expire" }
    }
  ]
}
JSON
)

for repo in "${REPOS[@]}"; do
  echo "==> ECR: ${repo}"
  if aws ecr describe-repositories --region "${REGION}" --repository-names "${repo}" >/dev/null 2>&1; then
    echo "    already exists, skipping create"
  else
    aws ecr create-repository \
      --region "${REGION}" \
      --repository-name "${repo}" \
      --image-scanning-configuration scanOnPush=true \
      >/dev/null
    echo "    created"
  fi

  aws ecr put-lifecycle-policy \
    --region "${REGION}" \
    --repository-name "${repo}" \
    --lifecycle-policy-text "${LIFECYCLE_POLICY}" \
    >/dev/null
  echo "    lifecycle policy applied"
done
echo

# ------------------------------------------------------------
# 2. GitHub OIDC identity provider
# ------------------------------------------------------------
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
echo "==> OIDC provider"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" >/dev/null 2>&1; then
  echo "    already exists"
else
  aws iam create-open-id-connect-provider \
    --url "${OIDC_URL}" \
    --thumbprint-list "${OIDC_THUMBPRINT}" \
    --client-id-list "sts.amazonaws.com" \
    >/dev/null
  echo "    created"
fi
echo

# ------------------------------------------------------------
# 3. IAM role with OIDC trust + ECR push policy
# ------------------------------------------------------------
TRUST_POLICY=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:${GITHUB_ORG}/${GITHUB_REPO}:*",
            "repo:${GITHUB_ORG}@${GITHUB_OWNER_ID}/${GITHUB_REPO}@${GITHUB_REPO_ID}:*"
          ]
        }
      }
    }
  ]
}
JSON
)

ECR_PUSH_POLICY=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ecr:GetAuthorizationToken"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
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
      ],
      "Resource": [
        "arn:aws:ecr:${REGION}:${ACCOUNT_ID}:repository/qr-api",
        "arn:aws:ecr:${REGION}:${ACCOUNT_ID}:repository/qr-frontend"
      ]
    }
  ]
}
JSON
)

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "==> IAM role: ${ROLE_NAME}"
if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  echo "    already exists, updating trust + policy"
  aws iam update-assume-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-document "${TRUST_POLICY}" \
    >/dev/null
else
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}" \
    --description "GitHub Actions OIDC role for ${GITHUB_ORG}/${GITHUB_REPO}" \
    >/dev/null
  echo "    created"
fi

aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "ecr-push" \
  --policy-document "${ECR_PUSH_POLICY}" \
  >/dev/null
echo "    inline policy applied"
echo

# ------------------------------------------------------------
# 4. Terraform state backend (S3 + DynamoDB lock)
# ------------------------------------------------------------
echo "==> Terraform state bucket: ${TFSTATE_BUCKET}"
if aws s3api head-bucket --bucket "${TFSTATE_BUCKET}" >/dev/null 2>&1; then
  echo "    already exists"
else
  aws s3api create-bucket \
    --region "${REGION}" \
    --bucket "${TFSTATE_BUCKET}" \
    >/dev/null
  aws s3api put-bucket-versioning \
    --bucket "${TFSTATE_BUCKET}" \
    --versioning-configuration Status=Enabled \
    >/dev/null
  aws s3api put-bucket-encryption \
    --bucket "${TFSTATE_BUCKET}" \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
    >/dev/null
  aws s3api put-public-access-block \
    --bucket "${TFSTATE_BUCKET}" \
    --public-access-block-configuration \
      '{"BlockPublicAcls":true,"IgnorePublicAcls":true,"BlockPublicPolicy":true,"RestrictPublicBuckets":true}' \
    >/dev/null
  aws s3api put-bucket-lifecycle-configuration \
    --bucket "${TFSTATE_BUCKET}" \
    --lifecycle-configuration \
      '{"Rules":[{"ID":"expire-noncurrent","Status":"Enabled","Filter":{},"NoncurrentVersionExpiration":{"NoncurrentDays":90}}]}' \
    >/dev/null
  echo "    created (versioning + SSE + block public + 90d noncurrent expire)"
fi
echo

echo "==> Terraform lock table: ${TFSTATE_DDB_TABLE}"
if aws dynamodb describe-table --table-name "${TFSTATE_DDB_TABLE}" >/dev/null 2>&1; then
  echo "    already exists"
else
  aws dynamodb create-table \
    --region "${REGION}" \
    --table-name "${TFSTATE_DDB_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    >/dev/null
  echo "    created"
fi
echo

# ------------------------------------------------------------
# 5. Output
# ------------------------------------------------------------
cat <<EOF

=================================================================
  Bootstrap complete. Now set these GitHub Actions variables:
=================================================================

  gh variable set AWS_ROLE_ARN --body "${ROLE_ARN}"
  gh variable set AWS_REGION   --body "${REGION}"

=================================================================
  Phase 3 (Terraform) will adopt these resources via import:
=================================================================

  terraform import module.s3.aws_s3_bucket.qr_codes                  zevlo-qr-platform-codes
  terraform import module.ecr.aws_ecr_repository.api                 ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/qr-api
  terraform import module.ecr.aws_ecr_repository.frontend            ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/qr-frontend
  terraform import module.iam.aws_iam_role.gha                       ${ROLE_NAME}
  terraform import module.iam.aws_iam_openid_connect_provider.github ${OIDC_ARN}
  terraform import module.tfstate.aws_s3_bucket.this                 ${TFSTATE_BUCKET}
  terraform import module.tfstate.aws_dynamodb_table.locks           ${TFSTATE_DDB_TABLE}

EOF
