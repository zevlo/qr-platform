# Preflight — qr-platform

Living checklist. Update as you complete items.

**Legend:** [x] done · [ ] todo · [!] blocked / needs decision

## Tooling

| Tool | Required by | Status |
|---|---|---|
| OrbStack (Docker 29.4.0) | P1, P2 | [x] |
| kubectl | P4, P5 | [x] installed |
| terraform v1.15.8 | P3 | [x] |
| helm | P3, P5 | [x] installed |
| aws CLI 2.36.2 | P2, P3 | [x] |
| gh CLI 2.96.0 | P0, P2 | [x] |
| mise 2026.7.11 | P0+ | [x] (manages project python/node) |
| python 3.12.13 (via mise) | P0, P1 | [x] matches Dockerfile pin |
| node 20.20.2 (via mise) | P0, P1 | [x] matches Dockerfile pin |
| npm 10.8.2 (via mise) | P0, P1 | [x] |
| trivy | P2 | [x] installed via brew |
| argocd CLI | P5 | [x] installed via brew |
| ruff, pytest, httpx | P2 | [x] pinned in `api/requirements-dev.txt` |

## Accounts / Access

- [x] GitHub authenticated as `zevlo` (token scopes: repo, workflow, read:org, delete_repo, gist)
- [x] AWS authenticated as `admin-zach` in account `746669194590`
- [x] AWS billing alarm set ($10 threshold)
- [x] Fork created: `github.com/zevlo/qr-platform` (forked from `rishabkumar7/devops-qr-code`)
- [x] S3 bucket created: `zevlo-qr-platform-codes` (us-east-1, ACLs enabled for upstream's `ACL='public-read'`)
- [!] **Homelab K8s cluster is DOWN** (`192.168.1.221:6443` unreachable) — must be brought back up before Phase 4 dev work. Not blocking Phase 0–2.
- [ ] Domain decision: owned domain vs `sslip.io` for TLS demos (defer to P4)

## Phase 0 — Local Verification ✅

- [x] Forked upstream to `zevlo/qr-platform`
- [x] Cloned to `/Users/za/projects/qr-platform/`
- [x] Set `origin` = `zevlo/qr-platform`, `upstream` = `rishabkumar7/devops-qr-code`
- [x] Project scaffold created (PREFLIGHT.md, AGENTS.md, root .gitignore, dir skeleton)
- [x] `mise.toml` added; python 3.12.13 + node 20.20.2 installed and active
- [x] Backend venv created at `api/.venv/`; all `requirements.txt` installed
- [x] Frontend `npm install` complete (149 packages)
- [x] **Justified edits to `api/main.py`:** `/health` endpoint · env-ified `bucket_name` · boto3 default credential chain
- [x] Updated `api/.env.example` with `BUCKET_NAME` and credential notes
- [x] Backend smoke test: `uvicorn main:app` starts, `/health` → 200, `/docs` → 200
- [x] Frontend smoke test: `npm run build` succeeds (5 static pages, 101 kB First Load JS)
- [x] S3 bucket `zevlo-qr-platform-codes` created with ACLs + ObjectWriter ownership
- [x] `api/.env` configured with `BUCKET_NAME`
- [x] **End-to-end test passed:** POST `http://localhost:8000/generate-qr/?url=https://github.com/zevlo/qr-platform` → JSON returned → object verified in S3 → public URL returns HTTP 200
- [x] `feat/containerization` branch checked out

### Notes

- **Frontend has 14 npm vulnerabilities** (5 moderate, 7 high, 2 critical) — upstream deps. Out of scope to patch (we operate, not rewrite). Track for "What I'd add next" in README.
- **boto3 client uses default credential chain** — local runs use `admin-zach` AWS CLI profile automatically; in containers via `~/.aws` volume mount; in k8s via IRSA (Phase 4).
- **Python 3.14 / Node 24 system versions are bypassed** in this project (mise picks up `mise.toml` automatically).

## Phase 1 — Containerization ✅

### Done

- [x] `front-end-nextjs/next.config.js` — enabled `output: 'standalone'`
- [x] `front-end-nextjs/src/app/page.js` — env-ified API URL via `process.env.NEXT_PUBLIC_API_URL` with `'http://localhost:8000'` fallback
- [x] `api/Dockerfile` — multi-stage Python (builder + runtime), python:3.12-slim, non-root `appuser`, HEALTHCHECK on `/health`
- [x] `front-end-nextjs/Dockerfile` — three-stage (deps, builder, runner), node:20-alpine, Next.js standalone
- [x] `api/.dockerignore` — strips venv, caches, secrets, .git, tests
- [x] `front-end-nextjs/.dockerignore` — strips node_modules, .next, secrets, .git
- [x] `docker-compose.yml` — two services + bridge network, `~/.aws` mount for default credential chain, build-time `NEXT_PUBLIC_API_URL` arg

### Verification — all passed

- [x] `docker compose build` — both images build without errors
- [x] `docker compose up -d` — both containers come up
- [x] `docker compose ps` — both services healthy
- [x] `curl http://localhost:8000/health` → `{"status":"ok"}`
- [x] Browser at http://localhost:3000 → submit URL → QR renders
- [x] Object appears in S3
- [x] `docker compose down` — clean teardown

### Image sizes (captured for README)

| Image | Size | Notes |
|---|---|---|
| `qr-platform-api:latest` | 320 MB | python:3.12-slim (~130 MB) + venv (~180 MB, pillow dominates) + curl (~10 MB) |
| `qr-platform-frontend:latest` | 222 MB | node:20-alpine (~50 MB) + Next.js standalone + static chunks |

**For comparison:** naive single-stage builds would be ~500 MB (api) and ~1 GB (frontend with full node_modules).

## Project Skeleton

```
qr-platform/
├── api/                          # upstream — FastAPI backend
│   ├── .venv/                    # local venv (gitignored)
│   ├── .dockerignore             # NEW P1
│   ├── Dockerfile                # NEW P1 — multi-stage Python
│   ├── main.py                   # EDITED P0: /health, env-ify bucket, default cred chain
│   │                             # EDITED P2: minimal ruff fixes (sorted imports, raise ... from e)
│   ├── test_main.py              # EDITED P2: fix pre-existing bug + mock S3
│   ├── requirements.txt          # upstream pinned deps
│   ├── requirements-dev.txt      # NEW P2 — ruff, pytest, httpx
│   ├── ruff.toml                 # NEW P2 — lint config
│   ├── .env                      # local S3 config (gitignored)
│   └── .env.example              # EDITED P0
├── front-end-nextjs/             # upstream — Next.js frontend
│   ├── node_modules/             # local install (gitignored)
│   ├── .dockerignore             # NEW P1
│   ├── Dockerfile                # NEW P1 — multi-stage Next.js standalone
│   ├── next.config.js            # EDITED P1: output: 'standalone'
│   ├── .eslintrc.json            # NEW P2 — required for `next lint` in CI
│   ├── package.json              # EDITED P2: eslint + eslint-config-next devDeps
│   └── src/app/page.js           # EDITED P1: env-ify API URL
├── k8s/                          # P4 — Kubernetes manifests (empty)
├── infrastructure/               # NEW P3 — Terraform (modules: vpc, eks, ecr, s3, iam-bootstrap, iam-irsa, secrets-manager, tfstate)
├── bootstrap/                    # NEW P2 — one-time AWS bootstrap (ECR + OIDC + IAM + tfstate backend)
├── .github/
│   ├── workflows/ci.yml          # NEW P2 — lint + pytest + matrix build + trivy + ECR push (OIDC)
│   ├── dependabot.yml            # NEW P2
│   └── README.md                 # NEW P2 — required vars, branch-protection notes
├── docs/plan.md                  # Full capstone plan
├── mise.toml                     # Pin python=3.12, node=20
├── docker-compose.yml            # NEW P1 — two-service dev stack
├── PREFLIGHT.md                  # This file
├── AGENTS.md                     # Context for AI coding sessions
└── .gitignore                    # Root-level ignores
```

## Phase 2 — CI/CD ✅

### Done

- [x] `api/requirements-dev.txt` — `ruff==0.15.22`, `pytest==9.1.1`, `httpx==0.24.1` (pinned for starlette 0.27 compat)
- [x] `api/ruff.toml` — rule set `E,F,I,UP,B`, line-length 100, py312 target
- [x] `api/main.py` — minimal lint fixes (sorted imports, `raise ... from e`); required for CI lint job
- [x] `api/test_main.py` — fixed pre-existing bug (endpoint expects `?url=` query param, not JSON body) and mocked boto3 so tests don't hit S3 in CI
- [x] `front-end-nextjs/.eslintrc.json` + `eslint` + `eslint-config-next` devDeps — required for `next lint` to run non-interactively
- [x] `.github/workflows/ci.yml` — `lint` (ruff + next lint) → `test` (pytest) → `build` matrix (api + frontend) with Trivy scan + SARIF upload → on `main` only, OIDC auth + push to ECR with `:sha` and `:latest`
- [x] `.github/dependabot.yml` — weekly update PRs for `github-actions`, `npm`, `pip`
- [x] `.github/README.md` — required vars, branch protection, Trivy rationale
- [x] `bootstrap/aws.sh` + `bootstrap/README.md` — idempotent AWS bootstrap (ECR repos + scan-on-push + lifecycle policy, OIDC IdP, IAM role with both `sub` claim formats)
- [x] GitHub Actions variables set: `AWS_ROLE_ARN`, `AWS_REGION` (no secrets — OIDC trust is the auth)

### Verification — all passed

- [x] Local: `ruff check .` clean, `pytest -v` 3 passed, `npm run lint` clean (1 informational warning)
- [x] CI on PR (run 29860310379) — lint, test, build (api), build (frontend) all green; push steps correctly skipped (`if: github.ref == 'refs/heads/main'`)
- [x] Bootstrap script ran idempotently against the existing OIDC IdP
- [x] Merged PR #1 to `main` via squash
- [x] CI on `main` (run 29861231453) — both images pushed to ECR; both images scanned; SARIF under Security → Code scanning alerts

### Notes / gotchas

- **OIDC `sub` claim uses GitHub's v2 ID format** for this repo: `repo:zevlo@104938351/qr-platform@1307854556:ref:...`. The IAM trust policy accepts both that and the textbook `repo:zevlo/qr-platform:*` form. If you fork this repo, re-derive the IDs and update the bootstrap script + trust policy.
- **Trivy runs warn-only** (`exit-code: 0`). Current HIGH/CRITICAL findings are in upstream-pinned deps we don't bump per AGENTS.md (`pillow 10.2`, `starlette 0.27`, `urllib3 1.26`). SARIF surfaces them under Security → Code scanning alerts. Hard-fail gate deferred to a future hardening pass.
- **`httpx==0.24.1`** pinned in dev deps because newer httpx (0.25+) breaks starlette 0.27's TestClient.
- **`next lint`** prints a Node 20 deprecation warning under GHA — cosmetic, will resolve when `actions/*` ship Node 24 defaults.

### ECR repos

- `746669194590.dkr.ecr.us-east-1.amazonaws.com/qr-api` — scan-on-push, lifecycle (10 tagged + 1d untagged)
- `746669194590.dkr.ecr.us-east-1.amazonaws.com/qr-frontend` — same

## Phase 3 — Terraform ✅

### Done

- [x] `bootstrap/aws.sh` extended — creates `zevlo-qr-platform-tfstate` S3 (versioned, SSE, block public, 90d noncurrent lifecycle) + `terraform-locks` DynamoDB table
- [x] `infrastructure/` skeleton — `backend.tf`, `versions.tf`, `providers.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `terraform.tfvars.example`, `README.md`, `up.sh`, `down.sh`
- [x] `modules/vpc/` — 2 AZ, public + private subnets (private unused), IGW, no NAT, S3 gateway endpoint + ECR/STS interface endpoints (with dedicated SG allowing 443 from VPC)
- [x] `modules/eks/` — cluster 1.31, managed node group 2× t3.medium, public API endpoint, dedicated cluster + node SGs, all 5 log types enabled
- [x] `modules/ecr/` — adopted both repos via `terraform import`, scan-on-push + lifecycle policy enforced in config, `prevent_destroy`
- [x] `modules/s3/` — adopted `zevlo-qr-platform-codes`, ownership + ACL config, IAM write policy for the api pod
- [x] `modules/iam-bootstrap/` — adopted OIDC IdP + `qr-platform-gha` role + inline ecr-push policy, both `sub` formats accepted (textbook + v2 ID), `prevent_destroy`
- [x] `modules/iam-irsa/` — created IRSA role `qr-platform-api` for `system:serviceaccount:qr-app:api`, attached to the S3 write policy
- [x] `modules/secrets-manager/` — one secret `qr-platform/api` with non-secret runtime config (BUCKET_NAME + AWS_REGION); real AWS auth is IRSA
- [x] `modules/tfstate/` — adopted state bucket + lock table, full config (versioning, SSE, public block, lifecycle) brought under Terraform ownership, `prevent_destroy`

### Verification — all passed

- [x] `terraform init` against remote S3 + DynamoDB backend
- [x] 7 resources adopted via `terraform import` (qr S3 bucket, both ECR repos, IAM role, OIDC IdP, state bucket, lock table) — zero destroy operations
- [x] `terraform plan` after imports: 42 to add, 7 to change (just default_tag additions + description punctuation), 0 to destroy
- [x] `terraform apply` — full EKS cluster + VPC + IRSA + secret created (apply was interrupted once by bash timeout; resumed via `terraform import` of the node group + IRSA role that had been created-but-not-stated, then re-applied to converge)
- [x] **First node-group bring-up revealed a real bug:** VPC interface endpoints inherited the VPC default SG, which didn't allow 443 from the node SG. Diagnosed via `kubectl get events` (ECR `i/o timeout` errors pulling `amazon-k8s-cni-init` and `kube-proxy`). Fixed by adding `aws_security_group.vpc_endpoints` allowing 443 from the VPC CIDR. Both nodes went Ready within 90s of re-apply.
- [x] `kubectl get nodes` → 2/2 Ready; `kubectl -n kube-system get pods` → all Running
- [x] `terraform destroy -target` on the four new modules — all 34 new resources destroyed, 0 orphaned ENIs left behind
- [x] Pre-existing resources (state bucket, lock table, ECR, OIDC, IAM role, QR bucket) preserved by `prevent_destroy`

### Cost

- **Up (~5 hours during P3 dev):** EKS control plane + 2× t3.medium + 3× interface endpoints + secrets manager ≈ $1.50 total
- **Down (current state):** state bucket + lock table + QR bucket + ECR repos = <$1/mo

### Handoff to Phase 4

`terraform output` exposes (after next `terraform apply`):
- `irsa_role_arn` — Phase 4 must annotate the `api` ServiceAccount with `eks.amazonaws.com/role-arn: <arn>`.
- `secrets_manager_secret_name` — Phase 5 (External Secrets Operator) syncs this into the cluster.
- `ecr_repositories` — Phase 4 manifests reference these image URIs.
- `eks_cluster_name` — `kubectl` context name after `./up.sh`.

### Notes / gotchas

- **No NAT gateway** (cost discipline). Nodes live in public subnets and use VPC endpoints to reach ECR/S3/STS.
- **EKS API endpoint is public** (`0.0.0.0/0`). Acceptable for the short-lived demo cluster. For real deployment, lock `public_access_cidrs`.
- **`terraform destroy` requires `-target`** on the four new modules because the seven adopted resources are protected with `prevent_destroy`. `down.sh` wraps this.
- **`.terraform.lock.hcl` is gitignored** in this single-operator repo. Re-enable in gitignore if collaborators join.
- **DynamoDB `dynamodb_table` backend arg is deprecated** in Terraform 1.10+ in favor of `use_lockfile`. Still works; will swap in a future Terraform upgrade.
- **One terraform apply was interrupted by bash timeout at 25 min.** Resources were created in AWS but not written to state. Recovery was: `terraform import` the two affected resources, then `terraform apply` again to converge. Lesson: terraform apply runs > 25 min need either a longer timeout or a `nohup` / `tmux` wrapper.

## Known Upstream Edits Required (track here, do in correct phase)

### Done

- [x] `api/requirements-dev.txt` — `ruff==0.15.22`, `pytest==9.1.1`, `httpx==0.24.1` (pinned for starlette 0.27 compat)
- [x] `api/ruff.toml` — rule set `E,F,I,UP,B`, line-length 100, py312 target
- [x] `api/main.py` — minimal lint fixes (sorted imports, `raise ... from e`); required for CI lint job
- [x] `api/test_main.py` — fixed pre-existing bug (endpoint expects `?url=` query param, not JSON body) and mocked boto3 so tests don't hit S3 in CI
- [x] `front-end-nextjs/.eslintrc.json` + `eslint` + `eslint-config-next` devDeps — required for `next lint` to run non-interactively
- [x] `.github/workflows/ci.yml` — `lint` (ruff + next lint) → `test` (pytest) → `build` matrix (api + frontend) with Trivy scan + SARIF upload → on `main` only, OIDC auth + push to ECR with `:sha` and `:latest`
- [x] `.github/dependabot.yml` — weekly update PRs for `github-actions`, `npm`, `pip`
- [x] `.github/README.md` — required vars, branch protection, Trivy rationale
- [x] `bootstrap/aws.sh` + `bootstrap/README.md` — idempotent AWS bootstrap (ECR repos + scan-on-push + lifecycle policy, OIDC IdP, IAM role with both `sub` claim formats)
- [x] GitHub Actions variables set: `AWS_ROLE_ARN`, `AWS_REGION` (no secrets — OIDC trust is the auth)

### Verification — all passed

- [x] Local: `ruff check .` clean, `pytest -v` 3 passed, `npm run lint` clean (1 informational warning)
- [x] CI on PR (run 29860310379) — lint, test, build (api), build (frontend) all green; push steps correctly skipped (`if: github.ref == 'refs/heads/main'`)
- [x] Bootstrap script ran idempotently against the existing OIDC IdP
- [x] Merged PR #1 to `main` via squash
- [x] CI on `main` (run 29861231453) — both images pushed to ECR; both images scanned; SARIF under Security → Code scanning alerts

### Notes / gotchas

- **OIDC `sub` claim uses GitHub's v2 ID format** for this repo: `repo:zevlo@104938351/qr-platform@1307854556:ref:...`. The IAM trust policy accepts both that and the textbook `repo:zevlo/qr-platform:*` form. If you fork this repo, re-derive the IDs and update the bootstrap script + trust policy.
- **Trivy runs warn-only** (`exit-code: 0`). Current HIGH/CRITICAL findings are in upstream-pinned deps we don't bump per AGENTS.md (`pillow 10.2`, `starlette 0.27`, `urllib3 1.26`). SARIF surfaces them under Security → Code scanning alerts. Hard-fail gate deferred to a future hardening pass.
- **`httpx==0.24.1`** pinned in dev deps because newer httpx (0.25+) breaks starlette 0.27's TestClient.
- **`next lint`** prints a Node 20 deprecation warning under GHA — cosmetic, will resolve when `actions/*` ship Node 24 defaults.

### ECR repos

- `746669194590.dkr.ecr.us-east-1.amazonaws.com/qr-api` — scan-on-push, lifecycle (10 tagged + 1d untagged)
- `746669194590.dkr.ecr.us-east-1.amazonaws.com/qr-frontend` — same

## Known Upstream Edits Required (track here, do in correct phase)

| Edit | File | Phase | Justification | Status |
|---|---|---|---|---|
| Add `/health` route | `api/main.py` | P0 | Required for k8s readiness/liveness probes | [x] done |
| Env-ify `bucket_name` | `api/main.py` | P0 | Hardcoded string is unoperational | [x] done |
| Use boto3 default credential chain | `api/main.py` | P0 | Supports `~/.aws/credentials` locally + IRSA in k8s without code changes | [x] done |
| Enable `output: 'standalone'` | `front-end-nextjs/next.config.js` | P1 | Required for multi-stage Next.js Docker build | [x] done |
| Env-ify API URL via `NEXT_PUBLIC_API_URL` | `front-end-nextjs/src/app/page.js:13` | P1 | Required for portable images across environments (Docker, k8s, etc.) | [x] done |
| Minimal ruff fixes (sorted imports, `raise ... from e`) | `api/main.py` | P2 | Required for CI lint job to pass | [x] done |
| Fix pre-existing test bug + mock boto3 | `api/test_main.py` | P2 | Pre-existing test posted JSON body to a query-param endpoint (always 422); CI shouldn't hit S3 | [x] done |
| Add `prometheus-fastapi-instrumentator` | `api/main.py` + `requirements.txt` | P5 | Exposes `/metrics` for Prometheus scrape | [ ] |
