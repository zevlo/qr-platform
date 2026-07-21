# `infrastructure/` — Phase 3 Terraform

All AWS infra that runs the platform lives here. Pre-existing resources (created in Phase 0 / Phase 2 / `bootstrap/aws.sh`) are adopted via `terraform import` and protected with `prevent_destroy`.

## Layout

```
infrastructure/
├── backend.tf              # S3 + DynamoDB backend config
├── versions.tf             # provider pins
├── providers.tf            # aws provider + default tags
├── variables.tf            # inputs
├── main.tf                 # module instantiation
├── outputs.tf              # cluster endpoint, IRSA role ARN, etc.
├── terraform.tfvars.example
├── up.sh / down.sh         # apply / destroy wrappers
└── modules/
    ├── vpc/                # 2 AZ, no NAT, VPC endpoints
    ├── eks/                # cluster 1.31 + managed node group
    ├── ecr/                # qr-api, qr-frontend (adopted)
    ├── s3/                 # qr-platform-codes bucket (adopted) + write policy
    ├── iam-bootstrap/      # OIDC IdP + GHA role (adopted)
    ├── iam-irsa/           # api pod IRSA role (new)
    ├── secrets-manager/    # non-secret runtime config (new)
    └── tfstate/            # state bucket + lock table (adopted)
```

## Apply / destroy

```bash
./up.sh        # apply + write kubeconfig
./down.sh      # destroy + clean up orphaned EKS ENIs
```

Both wrappers prompt for confirmation. `down.sh` is the right command whenever you're not actively demoing — keeps the AWS account at ~zero spend.

## Adopted resources

The first time you set this up, run `terraform import` for each pre-existing resource. The `bootstrap/aws.sh` script's output prints the exact commands.

| Resource | Address |
|---|---|
| S3 `zevlo-qr-platform-codes` | `module.s3.aws_s3_bucket.qr_codes` |
| ECR `qr-api` | `module.ecr.aws_ecr_repository.this["qr-api"]` |
| ECR `qr-frontend` | `module.ecr.aws_ecr_repository.this["qr-frontend"]` |
| IAM role `qr-platform-gha` | `module.iam_bootstrap.aws_iam_role.gha` |
| OIDC IdP | `module.iam_bootstrap.aws_iam_openid_connect_provider.github` |
| State bucket | `module.tfstate.aws_s3_bucket.this` |
| State lock table | `module.tfstate.aws_dynamodb_table.locks` |

After imports, `terraform plan` should show **zero diffs** on these resources — only creates for the new VPC, EKS, and IRSA pieces.

## Cost

| Component | Cost / mo when up |
|---|---|
| EKS control plane | $73 |
| 2× t3.medium nodes | $60 |
| VPC endpoints (3× interface + 1× gateway) | ~$21 |
| Secrets Manager (1 secret) | $0.40 |
| Total | **~$154/mo ÷ 30 ≈ $5/day** |

When destroyed: **<$1/mo** (state bucket + QR bucket + ECR = pennies).

## Handoff to Phase 4

`terraform output` exposes:
- `irsa_role_arn` — Phase 4 must annotate the `api` ServiceAccount with this ARN.
- `secrets_manager_secret_name` — Phase 5 (External Secrets Operator) syncs this into the cluster.
- `ecr_repositories` — Phase 4 manifests reference these image URIs.
- `eks_cluster_name` — `kubectl` context name after `up.sh`.

## Notes / gotchas

- **No NAT gateway.** Nodes live in public subnets. VPC endpoints to S3 (gateway) and ECR + STS (interface) cover what they need.
- **EKS API endpoint is public** (`0.0.0.0/0`) — acceptable for the short-lived demo cluster. For a real deployment, lock `public_access_cidrs` to your IP.
- **Cluster log types enabled**: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`. CloudWatch Logs cost is minor for the demo lifetime.
