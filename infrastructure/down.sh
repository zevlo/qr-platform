#!/usr/bin/env bash
# Destroy the demo EKS cluster + VPC. Returns the AWS account to ~zero spend.
# Pre-existing resources (state bucket, ECR repos, QR S3 bucket, OIDC IdP,
# GHA role) are protected with prevent_destroy and won't be touched.
set -euo pipefail
cd "$(dirname "$0")"

echo "About to terraform destroy. Pre-existing resources are protected."
read -rp "Continue? [y/N] " yn
[ "$yn" = "y" ] || { echo "aborted"; exit 1; }

terraform init -input=false
terraform destroy -input=false

# Clean up any orphaned ENIs that EKS sometimes leaves behind.
echo
echo "Checking for orphaned EKS network interfaces..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(terraform output -raw region 2>/dev/null || echo us-east-1)
ENIS=$(aws ec2 describe-network-interfaces \
  --region "$REGION" \
  --query "NetworkInterfaces[?starts_with(Description, 'EKS')].[NetworkInterfaceId]" \
  --output text || true)
if [ -n "$ENIS" ]; then
  echo "  orphaned ENIs: $ENIS"
  for eni in $ENIS; do
    aws ec2 delete-network-interface --network-interface-id "$eni" --region "$REGION" || true
  done
else
  echo "  none"
fi

echo
echo "Cluster destroyed. AWS account back to ~zero spend."
