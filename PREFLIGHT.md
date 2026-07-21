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
| python3 (3.14 local) | P0, P1 | [x] (note: pin 3.12 in Dockerfile) |
| node (24 local) | P0, P1 | [x] (note: pin 20 in Dockerfile) |
| npm 11.16.0 | P0, P1 | [x] |
| argocd CLI | P5 | [ ] **install before P5** |
| trivy | P2 | [ ] **install before P2** |

Install commands (when ready):

```bash
brew install trivy
brew install argocd
```

## Accounts / Access

- [x] GitHub authenticated as `zevlo` (token scopes: repo, workflow, read:org, delete_repo, gist)
- [x] AWS authenticated as `admin-zach` in account `746669194590`
- [ ] **AWS billing alarm set** ($10 threshold — do this before any `terraform apply`)
- [x] Fork created: `github.com/zevlo/qr-platform` (forked from `rishabkumar7/devops-qr-code`)
- [!] **Homelab K8s cluster is DOWN** (`192.168.1.221:6443` unreachable) — must be brought back up before Phase 4 dev work. Not blocking Phase 0–2.
- [ ] Domain decision: owned domain vs `sslip.io` for TLS demos (defer to P4)

## Phase 0 — Local Verification (½ day)

### Done

- [x] Forked upstream to `zevlo/qr-platform`
- [x] Cloned to `/Users/za/projects/qr-platform/`
- [x] Set `origin` = `zevlo/qr-platform`, `upstream` = `rishabkumar7/devops-qr-code`
- [x] Project scaffold created (PREFLIGHT.md, AGENTS.md, root .gitignore, dir skeleton)

### Manual — Backend

- [ ] `cd api && python3 -m venv .venv && source .venv/bin/activate`
- [ ] `pip install -r requirements.txt`
- [ ] Create `api/.env` from `api/.env.example` with real AWS keys
- [ ] Decide S3 bucket name (will be Terraformed in P3, but needed now for local run). Suggested: `zevlo-qr-platform-codes`
- [ ] **Create the S3 bucket in AWS** (console or `aws s3api create-bucket --bucket <name> --region <region>`)
- [ ] Update `bucket_name` in `api/main.py:32` (hardcoded `'YOUR_BUCKET_NAME'`)
- [ ] `uvicorn main:app --reload` → confirm http://localhost:8000/docs loads

### Manual — Frontend

- [ ] `cd front-end-nextjs && npm install`
- [ ] `npm run dev` → confirm http://localhost:3000 loads
- [ ] Submit a test URL → confirm QR renders → confirm object exists in S3

### Manual — Begin Phase 1

- [ ] `git checkout -b feat/containerization` (or merge the scaffold commit to main first — see git log)

## Project Skeleton

```
qr-platform/
├── api/                    # upstream — FastAPI backend
├── front-end-nextjs/       # upstream — Next.js frontend
├── k8s/                    # P4 — Kubernetes manifests (empty)
├── infrastructure/         # P3 — Terraform (empty)
├── .github/workflows/      # P2 — GitHub Actions (empty)
├── docs/plan.md            # Full capstone plan
├── PREFLIGHT.md            # This file
├── AGENTS.md               # Context for AI coding sessions
└── .gitignore              # Root-level ignores
```

## Known Upstream Edits Required (track here, do in correct phase)

| Edit | File | Phase | Justification |
|---|---|---|---|
| Add `/health` route | `api/main.py` | P1 | Required for k8s readiness/liveness probes |
| Env-ify `bucket_name` | `api/main.py:32` | P0/P1 | Hardcoded string is unoperational |
| Add `prometheus-fastapi-instrumentator` | `api/main.py` + `requirements.txt` | P5 | Exposes `/metrics` for Prometheus scrape |
| Enable `output: 'standalone'` | `front-end-nextjs/next.config.js` | P1 | Required for multi-stage Next.js Docker build |
