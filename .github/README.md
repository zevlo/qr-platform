# `.github/` — CI configuration and required repo settings

## Required GitHub Actions **variables** (not secrets)

Set via `gh variable set <NAME> --body <value>` or **Settings → Secrets and variables → Actions → Variables**.

| Variable | Example | Purpose |
|---|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::746669194590:role/qr-platform-gha` | Role GitHub Actions assumes via OIDC |
| `AWS_REGION` | `us-east-1` | Region of the ECR repos |

No AWS secrets are stored. Authentication to AWS happens exclusively via OIDC trust between GitHub and the IAM role created by [`bootstrap/aws.sh`](../bootstrap/).

## Workflows

| File | Trigger | What it does |
|---|---|---|
| [`workflows/ci.yml`](./workflows/ci.yml) | `push` to `main`, any PR to `main` | lint (ruff + next lint) → pytest → matrix build (api + frontend) with Trivy scan + SARIF upload → on `main` only, OIDC login + push to ECR with `:sha` and `:latest` tags |

## Branch protection (recommended after Phase 2 merges)

For `main`:
- Require pull request before merging
- Require status checks to pass: `lint`, `test`, `build (api)`, `build (frontend)`
- Require branches up to date before merging
- Squash merges only
- Do not allow force pushes

## Notes

- `concurrency: ci-${{ github.ref }}` cancels superseded runs on the same ref.
- Trivy fails CI on `HIGH,CRITICAL` findings. If a base-image CVE blocks the build, either bump the base SHA in the Dockerfile (preferred) or add a temporary `.trivyignore` with a justification + expiry date.
- SARIF results land under **Security → Code scanning alerts**.
