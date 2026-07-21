# Preflight — qr-platform

Living checklist. Update as you complete items.

**Legend:** [x] done · [ ] todo · [!] blocked / needs decision

## Tooling

| Tool | Required by | Status |
|---|---|---|
| docker 29.4.0 | P1, P2 | [x] |
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

## Accounts / Access

- [x] GitHub authenticated as `zevlo` (token scopes: repo, workflow, read:org, delete_repo, gist)
- [x] AWS authenticated as `admin-zach` in account `746669194590`
- [x] AWS billing alarm set ($10 threshold)
- [x] Fork created: `github.com/zevlo/qr-platform` (forked from `rishabkumar7/devops-qr-code`)
- [!] **Homelab K8s cluster is DOWN** (`192.168.1.221:6443` unreachable) — must be brought back up before Phase 4 dev work. Not blocking Phase 0–2.
- [ ] Domain decision: owned domain vs `sslip.io` for TLS demos (defer to P4)

## Phase 0 — Local Verification (½ day)

### Done

- [x] Forked upstream to `zevlo/qr-platform`
- [x] Cloned to `/Users/za/projects/qr-platform/`
- [x] Set `origin` = `zevlo/qr-platform`, `upstream` = `rishabkumar7/devops-qr-code`
- [x] Project scaffold created (PREFLIGHT.md, AGENTS.md, root .gitignore, dir skeleton)
- [x] `mise.toml` added; python 3.12.13 + node 20.20.2 installed and active
- [x] Backend venv created at `api/.venv/`; all `requirements.txt` installed
- [x] Frontend `npm install` complete (149 packages)
- [x] **Justified edits to `api/main.py`:**
  - Added `/health` endpoint (`{"status":"ok"}`)
  - Env-ified `bucket_name` → `os.getenv("BUCKET_NAME", "YOUR_BUCKET_NAME")`
  - Refactored boto3 to use default credential chain (supports `~/.aws/credentials`, IRSA in k8s)
- [x] Updated `api/.env.example` with `BUCKET_NAME` and credential notes
- [x] Backend smoke test: `uvicorn main:app` starts, `/health` → 200, `/docs` → 200
- [x] Frontend smoke test: `npm run build` succeeds (5 static pages, 101 kB First Load JS)
- [x] `feat/containerization` branch checked out

### Remaining Manual — End-to-End Verification

These require an S3 bucket (the app writes to S3 on every QR generation — this is app runtime, not infra deploy):

- [ ] **Decide S3 bucket name + region** (suggested: `zevlo-qr-platform-codes`, region matching your AWS profile)
- [ ] Create the bucket: `aws s3api create-bucket --bucket <name> --region <region> [--create-bucket-configuration LocationConstraint=<region>]`
- [ ] Copy `api/.env.example` → `api/.env`, set `BUCKET_NAME=<name>`
- [ ] Terminal 1: `cd api && source .venv/bin/activate && uvicorn main:app --reload`
- [ ] Terminal 2: `cd front-end-nextjs && npm run dev`
- [ ] Browser → http://localhost:3000 → submit URL → confirm QR renders
- [ ] `aws s3 ls s3://<name>/qr_codes/` → confirm object exists

### Notes

- **Frontend has 14 npm vulnerabilities** (5 moderate, 7 high, 2 critical) — upstream deps. Out of scope to patch (we operate, not rewrite). Track for "What I'd add next" in README.
- **boto3 client now uses default credential chain** — local runs use your `admin-zach` AWS CLI profile automatically; no need to set AWS_ACCESS_KEY/AWS_SECRET_KEY in `.env` unless overriding.
- **Python 3.14 / Node 24 system versions are bypassed** when in this project (mise picks up `mise.toml` automatically).

## Project Skeleton

```
qr-platform/
├── api/                    # upstream — FastAPI backend
│   ├── .venv/              # local venv (gitignored)
│   └── main.py             # EDITED: /health, env-ify bucket, default cred chain
├── front-end-nextjs/       # upstream — Next.js frontend
│   └── node_modules/       # local install (gitignored)
├── k8s/                    # P4 — Kubernetes manifests (empty)
├── infrastructure/         # P3 — Terraform (empty)
├── .github/workflows/      # P2 — GitHub Actions (empty)
├── docs/plan.md            # Full capstone plan
├── mise.toml               # Pin python=3.12, node=20
├── PREFLIGHT.md            # This file
├── AGENTS.md               # Context for AI coding sessions
└── .gitignore              # Root-level ignores
```

## Known Upstream Edits Required (track here, do in correct phase)

| Edit | File | Phase | Justification | Status |
|---|---|---|---|---|
| Add `/health` route | `api/main.py` | P0 | Required for k8s readiness/liveness probes | [x] done |
| Env-ify `bucket_name` | `api/main.py` | P0 | Hardcoded string is unoperational | [x] done |
| Use boto3 default credential chain | `api/main.py` | P0 | Supports `~/.aws/credentials` locally + IRSA in k8s without code changes; removes static keys from `.env` | [x] done |
| Enable `output: 'standalone'` | `front-end-nextjs/next.config.js` | P1 | Required for multi-stage Next.js Docker build | [ ] |
| Add `prometheus-fastapi-instrumentator` | `api/main.py` + `requirements.txt` | P5 | Exposes `/metrics` for Prometheus scrape | [ ] |
