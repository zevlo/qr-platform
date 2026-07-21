#!/usr/bin/env bash
# Apply the demo EKS cluster + VPC + IAM. Cost ~$5/day when up.
# `terraform destroy` is the inverse — use down.sh to park.
set -euo pipefail
cd "$(dirname "$0")"

echo "About to terraform apply. Cost ~\$5/day while the cluster is up."
read -rp "Continue? [y/N] " yn
[ "$yn" = "y" ] || { echo "aborted"; exit 1; }

terraform init -input=false
terraform apply -input=false

CLUSTER=$(terraform output -raw eks_cluster_name)
REGION=$(terraform output -raw region)
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --alias "$CLUSTER"
echo
echo "Cluster is up. Context '$CLUSTER' is now your current kubectl context."
echo "When done, run: ./down.sh"
