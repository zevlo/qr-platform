# AGENTS.md — qr-platform

Context for AI coding sessions (opencode, Claude, Cursor). Read this first.

## Project

Fork-and-operate portfolio project. Take an existing two-service app (Next.js frontend + FastAPI backend → S3) and harden it with Docker, GitHub Actions, Terraform, EKS, and Prometheus. **You are operating the app, not rewriting it.**

Upstream: `github.com/rishabkumar7/devops-qr-code` (set as `upstream` remote)
Our fork: `github.com/zevlo/qr-platform` (set as `origin` remote)
Local path: `/Users/za/projects/qr-platform/`

Full plan: [`docs/plan.md`](./docs/plan.md)
Living status: [`PREFLIGHT.md`](./PREFLIGHT.md)

## Stack

- **App layer (upstream, do not modify except where justified in PREFLIGHT.md):**
  - Backend: Python 3.12 / FastAPI 0.105 / uvicorn / boto3 / qrcode / pillow
  - Frontend: Node 20 / Next.js 14.0.4 / React 18 / Tailwind / axios
- **Platform layer (ours to build):**
  - Containers: Docker (multi-stage, non-root, pinned versions)
  - CI/CD: GitHub Actions with OIDC auth to AWS (no static keys)
  - Registry: AWS ECR
  - IaC: Terraform 1.15 (modules: vpc, eks, ecr, s3, iam, secrets-manager)
  - Orchestration: Kubernetes (homelab dev → EKS demo → destroy)
  - GitOps: ArgoCD
  - Observability: kube-prometheus-stack (Prometheus + Grafana + Alertmanager)

## Branch Strategy

`main` is the integration branch. Each phase gets its own `feat/*` branch merged via PR.

- `feat/containerization` — Phase 1 (Dockerfiles, docker-compose)
- `feat/cicd` — Phase 2 (GitHub Actions, ECR push, trivy scan) ✅ merged via PR #1
- `feat/terraform` — Phase 3 (AWS infra modules)
- `feat/k8s` — Phase 4 (manifests, ingress, TLS)
- `feat/observability` — Phase 5 (ArgoCD, Prometheus, dashboards, alerts)

## Key Files

- `api/main.py` — FastAPI app. **No `/health` endpoint yet** (add in P1). `bucket_name` is hardcoded at line 32 (env-ify).
- `api/requirements.txt` — pinned deps. Will add `prometheus-fastapi-instrumentator` in P5.
- `front-end-nextjs/next.config.js` — currently empty. Add `output: 'standalone'` in P1.
- `api/.env.example` — template for AWS keys. Never commit real `.env`.

## Don'ts

- **Don't commit `.env`** anywhere (root or per-service). Root `.gitignore` covers this.
- **Don't run `terraform apply` without confirming cost** — EKS = ~$73/mo control plane + ~$60/mo nodes if left on.
- **Don't push to `main` directly** — use PR per branch strategy.
- **Don't modify upstream app logic beyond what's justified in PREFLIGHT.md** — the point is operating, not rewriting.
- **Don't use long-lived AWS credentials in GitHub Actions** — use OIDC via `aws-actions/configure-aws-credentials@v4`.

## Phase Status

| Phase | Status | Branch |
|---|---|---|
| 0 — Fork + local verify | ✅ done (commit 84dff4e) | `main` |
| 1 — Containerization | ✅ done (this branch) | `feat/containerization` |
| 2 — CI/CD | ✅ done | `feat/cicd` |
| 3 — Terraform | not started | `feat/terraform` |
| 4 — Kubernetes | not started | `feat/k8s` |
| 5 — GitOps + Observability | not started | `feat/observability` |

## Commands Cheat Sheet

```bash
# Backend (from api/)
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload

# Frontend (from front-end-nextjs/)
npm install
npm run dev

# Sync with upstream (occasionally)
git fetch upstream
git checkout main
git merge upstream/main  # or rebase

# Terraform (Phase 3+, from infrastructure/)
terraform init
terraform plan
terraform apply
terraform destroy  # do this whenever not actively demoing
```
