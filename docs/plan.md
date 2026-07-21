# DevOps Capstone — QR Code Generator

**Created:** July 2026
**Timeline:** 2 weeks part-time (MVP ships in 5 days; production layer in days 6–14)
**Approach:** Manifests-first on homelab K8s → Terraform EKS for cloud demo → destroy to control cost
**Scope:** Take [rishabkumar7/devops-qr-code](https://github.com/rishabkumar7/devops-qr-code) (Next.js frontend + FastAPI backend → S3) and harden it with Docker, GitHub Actions, Terraform, K8s, and Prometheus — full DevOps lifecycle.
**Purpose:** Portfolio keystone. Exercises every tool in your confirmed stack (AWS / K8s / Docker / Terraform / GHA) **and** closes the observability gap. Small enough to actually finish.

**Upstream:** fork to your GitHub → `github.com/<you>/devops-qr-code`
**Languages:** JS 51.8% · Python 38.5% · CSS 9.7% (you are not modifying the app — you are operating it)

---

## Why This Project

- **Stack match is exact.** AWS, K8s, Docker, Terraform, GitHub Actions — every tool in your `job-search-plan.md` confirmed stack.
- **Closes the biggest gap.** README explicitly lists *monitoring* as a goal → Prometheus + Grafana + Alertmanager on the cluster closes your known observability hole before interview loops.
- **Two-service architecture forces real platform thinking.** Frontend ↔ backend networking, secrets, env injection, ingress routing — not a trivial single-container toy.
- **Finishable in 2 weeks.** Unlike the F1 dashboard, the app code already works. Your job is the platform around it.
- **Memorable demo.** Paste a URL → see a QR code rendered live → explain "and here's the Prometheus panel showing the request latency." Recruiters remember it.

**What it is NOT:**
- Not a from-scratch app — you fork and operate
- Not a multi-region HA production system (single EKS cluster, single AZ tolerance is fine for portfolio)
- Not a replacement for the F1 dashboard — this is the *DevOps-platform* portfolio piece; F1 is the *AWS-event-driven* piece. Different lanes.

---

## Architecture (Target End State)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          DEVELOPER LOOP                                   │
│                                                                          │
│   git push origin main  ──►  GitHub Actions  ──►  AWS ECR               │
│                                  │             (api + frontend images)   │
│                                  ▼                                        │
│                             updates manifest repo                         │
│                                  │                                        │
│                                  ▼                                        │
│   ArgoCD (in cluster)  ◄── watches git  ──►  syncs manifests to EKS     │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│                            RUNTIME — EKS CLUSTER                          │
│                                                                          │
│   Internet                                                               │
│      │                                                                   │
│      ▼                                                                   │
│   [ NGINX Ingress Controller ]  ◄── cert-manager (Let's Encrypt)        │
│      │                                                                   │
│      ├──► /  ──────► [ frontend-nextjs Service ]                        │
│      │                   └──► [ frontend Deployment ]                   │
│      │                          (Next.js standalone, port 3000)         │
│      │                                                                   │
│      └──► /api  ────► [ api-fastapi Service ]                           │
│                          └──► [ api Deployment ]                        │
│                                 (uvicorn, port 8000)                    │
│                                      │                                   │
│                                      ▼                                   │
│                               [ AWS S3 ]  (QR code bucket)              │
│                                                                          │
│   [ External Secrets Operator ]  ──►  AWS Secrets Manager / Parameter   │
│                                                                          │
│   [ kube-prometheus-stack ]                                             │
│      ├── Prometheus  (scrapes api + frontend + node exporters)          │
│      ├── Grafana     (dashboards: HTTP RPS, p99 latency, error rate,    │
│      │                pod CPU/mem, S3 put latency)                       │
│      └── Alertmanager (PagerDuty / Slack webhook for SLO burn)          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 0 — Fork + Local Verification (½ day)

Confirm the app runs before changing anything.

- [ ] Fork `rishabkumar7/devops-qr-code` to your GitHub
- [ ] Clone locally
- [ ] **Backend:** `python -m venv .venv` · `pip install -r api/requirements.txt` · `.env` from `.env.example` with AWS keys · update `BUCKET_NAME` in `api/main.py` · `uvicorn main:app --reload` → http://localhost:8000
- [ ] **Frontend:** `npm install` in `front-end-nextjs/` · `npm run dev` → http://localhost:3000
- [ ] **Test:** submit a URL → confirm QR appears → confirm object exists in S3
- [ ] `git checkout -b feat/containerization` to begin work

**Branch strategy for the capstone:** `main` (protected) · `feat/containerization` · `feat/cicd` · `feat/terraform` · `feat/k8s` · `feat/observability`. Merge each phase via PR (your own GHA workflow will validate them — eat your own dog food).

---

## Phase 1 — Containerization (1 day)

### Backend Dockerfile (`api/Dockerfile`)

- [ ] Base: `python:3.12-slim` (match the `.python-version` if pinned upstream)
- [ ] Multi-stage if you want bonus points: builder stage installs requirements, final stage copies venv
- [ ] Non-root user (`uvicorn` should never run as root)
- [ ] Healthcheck: `curl localhost:8000/health` (add a `/health` route to `main.py` if missing — small justified edit)
- [ ] `CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]`

### Frontend Dockerfile (`front-end-nextjs/Dockerfile`)

- [ ] Multi-stage build **required** for Next.js:
  - Stage 1 (`deps`): install node_modules
  - Stage 2 (`builder`): `npm run build` with `NEXT_PUBLIC_API_URL` build-arg
  - Stage 3 (`runner`): `node:20-alpine`, copy `.next/standalone` + `.next/static` + `public/`, expose 3000
- [ ] Enable Next.js `output: 'standalone'` in `next.config.js` (small justified edit)
- [ ] Non-root user (`nextjs`)

### `docker-compose.yml` (root)

- [ ] Two services: `api` + `frontend`
- [ ] Network: `app-net` (bridge)
- [ ] Frontend env: `API_URL=http://api:8000` (compose DNS)
- [ ] `aws-vault` or `.env` injection for AWS creds (never commit `.env`)

### `.dockerignore` for both

`node_modules` · `.next` · `.venv` · `__pycache__` · `.env` · `.git`

### Verify

`docker compose up --build` → http://localhost:3000 → submit URL → QR renders → S3 has object.

---

## Phase 2 — CI/CD with GitHub Actions (1–2 days)

### Registries (pick one)

- **Recommended: AWS ECR** — fits your AWS story, IaC-managed in Phase 3, no third-party account
- Alternative: Docker Hub (simpler, less AWS-aligned)

### `.github/workflows/ci.yml` (on every PR + push to main)

- [ ] **Lint job:** Python `ruff` + JS `npm run lint` (add config if missing)
- [ ] **Build job (matrix: api, frontend):** build Docker image, scan with `trivy` (free), push to ECR with two tags: `:${{ github.sha }}` and `:latest`
- [ ] **Test job:** smoke-test each image — `curl /health` on api, `curl /` on frontend
- [ ] OIDC auth to AWS (no long-lived keys): `aws-actions/configure-aws-credentials@v4` with `role-to-assume`

### `.github/workflows/deploy.yml` (on push to main, after CI passes)

- [ ] Update manifest repo (or this repo's `k8s/` dir) with new image tag
- [ ] Commit back via `gh-pages`-style bot, OR trigger ArgoCD webhook
- [ ] This is the GitOps handoff — Phase 5 picks it up

### Secrets

- [ ] GitHub Actions → AWS IAM role via OIDC (no static credentials — this is a portfolio flex, do it right)
- [ ] No `.env` in the repo, ever

---

## Phase 3 — Infrastructure as Code with Terraform (2 days)

`infrastructure/` directory. Remote state in S3 + DynamoDB lock.

### Modules

- [ ] `modules/vpc/` — 2 AZ public + private subnets, NAT gateway (or skip NAT and use public endpoints for portfolio — be honest in README about cost tradeoff)
- [ ] `modules/eks/` — EKS cluster (Kubernetes 1.30+), managed node group (2× `t3.medium`)
- [ ] `modules/ecr/` — two repos: `qr-api`, `qr-frontend` (with image scanning + lifecycle policy)
- [ ] `modules/s3/` — QR code bucket (private, versioned, lifecycle to expire after 30 days)
- [ ] `modules/iam/` — IRSA roles for: api pod (S3 access), External Secrets, ArgoCD, cert-manager
- [ ] `modules/secrets-manager/` — secret containing AWS keys the api pod actually uses at runtime (only if api needs to write to S3 directly from the pod — yes per upstream)

### Workflow

- [ ] `terraform init` → `terraform plan` → `terraform apply` from your laptop
- [ ] **Bonus:** wrap in GitHub Actions `terraform-apply.yml` workflow that runs on tag push (proper GitOps for infra). Higher portfolio value.
- [ ] **Cost discipline:** `terraform destroy` when not demoing. EKS control plane is ~$0.10/hr ($73/mo) + nodes (~$60/mo for 2× t3.medium). Don't leave it running.

### Helm releases via Terraform `helm` provider (or separate step)

- [ ] NGINX Ingress Controller
- [ ] kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
- [ ] ArgoCD
- [ ] External Secrets Operator
- [ ] cert-manager

---

## Phase 4 — Kubernetes Manifests (1–2 days)

`k8s/` directory, one namespace `qr-app`.

### Backend (`k8s/api.yaml`)

- [ ] `Deployment` — image `${ECR_URI}/qr-api:TAG`, port 8000, readiness + liveness probes on `/health`, resource requests/limits, env from Secret
- [ ] `Service` — ClusterIP, port 8000
- [ ] `Secret` (or ExternalSecret pulling from Secrets Manager) — AWS keys
- [ ] `PodDisruptionBudget` — minAvailable 1 (only meaningful if you bump replicas)

### Frontend (`k8s/frontend.yaml`)

- [ ] `Deployment` — image `${ECR_URI}/qr-frontend:TAG`, port 3000, probes, resource limits
- [ ] `Service` — ClusterIP, port 3000
- [ ] ConfigMap with `API_URL=http://api.qr-app.svc.cluster.local:8000` (cluster DNS — no S3 ingress needed for backend)

### Ingress (`k8s/ingress.yaml`)

- [ ] NGINX Ingress
- [ ] Two rules: `/` → frontend, `/api` → api (rewrite target for `/api`)
- [ ] TLS via cert-manager + Let's Encrypt (use a domain you control, or `sslip.io` for portfolio demo)

### Verify

- [ ] `kubectl apply -f k8s/`
- [ ] `kubectl get pods -n qr-app` — all Running
- [ ] `kubectl get ingress -n qr-app` — grab hostname
- [ ] Hit hostname in browser → submit URL → QR renders → object in S3

---

## Phase 5 — GitOps + Observability (2–3 days, this is where the portfolio gold is)

### GitOps with ArgoCD

- [ ] Install ArgoCD in cluster (Terraform helm provider already did this in Phase 3)
- [ ] `Application` CRD pointing at your repo `k8s/` directory
- [ ] Auto-sync + auto-prune + self-heal enabled
- [ ] Demo the loop: change a manifest → push → ArgoCD reconciles within 30s. **This is the demo recruiters remember.**

### Observability with kube-prometheus-stack

- [ ] Helm install (via Terraform) — Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics
- [ ] **Instrument the API:** add `prometheus-fastapi-instrumentator` to `main.py` (small justified edit, ~5 lines). Exposes `/metrics`.
- [ ] **ServiceMonitor** for the api (label `monitoring: prometheus`)
- [ ] **Grafana dashboards:**
  - Import the official FastAPI dashboard as a starting point
  - Build a custom "QR Generator" dashboard: HTTP RPS by route, p50/p99 latency, error rate, S3 PutObject latency, pod CPU/memory
- [ ] **Alerts:**
  - `HighErrorRate`: 5xx > 5% for 5 min
  - `HighLatency`: p99 > 1s for 5 min
  - `PodRestart`: any pod restarts > 2 in 10 min
  - Route to a Slack webhook (free, demo-able)

### What this proves

You can build a full SRE-grade platform: not just "I deployed pods," but "I deploy pods with SLOs, dashboards, and alerts." That's a mid-level DevOps/SRE story, not a junior one.

---

## Cost-Aware Strategy

EKS gets expensive fast if you leave it on.

| Approach | When | Cost |
|---|---|---|
| Develop manifests on homelab K8s cluster (you already have one) | Phase 1, 4, 5 dev | $0 |
| `kind` or `minikube` locally for fast iteration | Phase 4 iteration | $0 |
| Terraform `apply` to AWS for end-to-end demo + Loom recording | Phase 3 + final demo | ~$3–5 per demo day |
| `terraform destroy` immediately after demo | Always | — |

**Portfolio story angle:** "Developed on homelab K8s, validated on AWS EKS — same manifests, two environments." That's exactly the kind of platform engineering story that lands interviews.

---

## Timeline Mapped to Job Search

This runs **in parallel** with `job-search-plan.md`, not blocking applications.

| Job-search week | Capstone focus | Output |
|---|---|---|
| **Week 1** (packaging) | Phase 0 + 1 + 2 (local, containers, CI) | Fork live, both images in ECR, GHA workflow passing — add to GitHub pinned repos **day 7** |
| **Week 2** (publish + first applications) | Phase 3 + 4 (Terraform EKS + K8s manifests) | Live on EKS — record Loom demo, write blog post #4 |
| **Week 3** (publish + scale) | Phase 5 (ArgoCD + Prometheus + Grafana) | Closes observability gap before interview loops ramp |
| **Week 4** (convert) | Polish README, dashboard screenshots, architecture diagram | Repo is interview-ready |

**If time slips:** ship Phase 0–4 as the portfolio piece. Phase 5 is the multiplier but not required — better to ship 4 polished phases than 5 half-done.

---

## README (this is the artifact recruiters read)

Your fork's README overrides upstream. Required sections:

1. **One-line summary** with link to live demo (if still up) or Loom
2. **Architecture diagram** (the one above, redrawn cleanly)
3. **What I added** (bulleted: Dockerfiles, GHA, Terraform, k8s manifests, ArgoCD, monitoring)
4. **Tech stack** (only what you can defend in interview)
5. **Quickstart** — `terraform apply` + `kubectl apply` commands that actually work
6. **Cost-aware note** — what it costs to run, why it's usually destroyed
7. **What I'd add next** (HPA, multi-region, FSxX for S3 mounts, OpenTelemetry traces) — shows depth without overcommitting
8. **Link back** to your blog post on the build

---

## Blog Post Plan

**Slot:** Blog post #4 in `blog-strategy.md` (between "Kubernetes 101" and "Homelab / GitOps 101").

**Title options:**
- "From Fork to Production: Hardening a Two-Service App with the Full DevOps Stack"
- "Same Manifests, Two Clusters: Developing on Homelab K8s, Deploying to EKS"
- "GitOps from Zero: ArgoCD, Prometheus, and a QR Code Generator"

**Structure:** Problem (sample app, no DevOps) → Decisions (why ECR, why EKS, why ArgoCD) → Build log (each phase with one gotcha) → Demo (screenshots + Loom) → What I'd do differently.

**Distribution:** r/devops, r/kubernetes, K8s Slack `#showcase`, Hashnode + Dev.to cross-post. This is a strong piece — angle for Hacker News if the writeup is sharp.

---

## Resume Bullets (drop-in ready)

> Containerized a multi-service application (Next.js + FastAPI) with multi-stage Docker builds, deployed to AWS EKS via Terraform-provisioned infrastructure, and shipped through a GitHub Actions CI/CD pipeline using OIDC auth to AWS — no static credentials in the repo.

> Implemented GitOps deployment with ArgoCD and full observability with kube-prometheus-stack: custom Grafana dashboards tracking HTTP RPS, p99 latency, and S3 write latency, plus Alertmanager rules routing to Slack.

> Developed Kubernetes manifests iteratively on a homelab K8s cluster and validated on AWS EKS — same manifests, two environments, demonstrating environment-portable platform engineering.

---

## Interview Questions This Project Answers

- "Tell me about your DevOps experience." → Lead with this.
- "How would you set up CI/CD for a two-service app?" → Walk through Phase 2.
- "Describe your approach to IaC." → Terraform modules, remote state, OIDC.
- "How do you handle secrets?" → IRSA + Secrets Manager + External Secrets Operator.
- "What's your monitoring story?" → Prometheus + Grafana + Alertmanager. *Closes the gap.*
- "How does GitOps work?" → ArgoCD watching the manifest dir, auto-sync.
- "Tell me about a hard bug." → The Next.js standalone build / env injection / ingress rewrite snag you'll inevitably hit.

---

## Linked Files

- [`job-search-plan.md`](./job-search-plan.md) — master plan; this capstone closes the observability gap
- [`blog-strategy.md`](./blog-strategy.md) — slot this as post #4
- [`homelab-setup.html`](./homelab-setup.html) / [`mac-mini-setup.md`](./mac-mini-setup.md) — the dev environment for Phase 1/4/5
- [`devops-roadmap.md`](./devops-roadmap.md) — skill-ladder context
