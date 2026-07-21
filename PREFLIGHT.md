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
│   ├── .env                      # local S3 config (gitignored)
│   └── .env.example              # EDITED P0
├── front-end-nextjs/             # upstream — Next.js frontend
│   ├── node_modules/             # local install (gitignored)
│   ├── .dockerignore             # NEW P1
│   ├── Dockerfile                # NEW P1 — multi-stage Next.js standalone
│   ├── next.config.js            # EDITED P1: output: 'standalone'
│   └── src/app/page.js           # EDITED P1: env-ify API URL
├── k8s/                          # P4 — Kubernetes manifests (empty)
├── infrastructure/               # P3 — Terraform (empty)
├── .github/workflows/            # P2 — GitHub Actions (empty)
├── docs/plan.md                  # Full capstone plan
├── mise.toml                     # Pin python=3.12, node=20
├── docker-compose.yml            # NEW P1 — two-service dev stack
├── PREFLIGHT.md                  # This file
├── AGENTS.md                     # Context for AI coding sessions
└── .gitignore                    # Root-level ignores
```

## Known Upstream Edits Required (track here, do in correct phase)

| Edit | File | Phase | Justification | Status |
|---|---|---|---|---|
| Add `/health` route | `api/main.py` | P0 | Required for k8s readiness/liveness probes | [x] done |
| Env-ify `bucket_name` | `api/main.py` | P0 | Hardcoded string is unoperational | [x] done |
| Use boto3 default credential chain | `api/main.py` | P0 | Supports `~/.aws/credentials` locally + IRSA in k8s without code changes | [x] done |
| Enable `output: 'standalone'` | `front-end-nextjs/next.config.js` | P1 | Required for multi-stage Next.js Docker build | [x] done |
| Env-ify API URL via `NEXT_PUBLIC_API_URL` | `front-end-nextjs/src/app/page.js:13` | P1 | Required for portable images across environments (Docker, k8s, etc.) | [x] done |
| Add `prometheus-fastapi-instrumentator` | `api/main.py` + `requirements.txt` | P5 | Exposes `/metrics` for Prometheus scrape | [ ] |
