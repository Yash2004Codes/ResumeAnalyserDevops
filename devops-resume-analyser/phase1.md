# Phase 1: Free-Tier Cloud-Native Build (what has been done)

Date: 2026-10-14
Status: code written, **not yet validated or deployed** (no `terraform` or Python was available on the build machine). The CI pipeline will run `terraform validate` and `pytest` on the first push.

## Goal
Run the Resume Analyzer on AWS at ~$0: one `t3.micro` EC2 running Docker Compose, with CI/CD from GitHub Actions. This replaces the earlier paid design in `PLAN.md` (ALB, NAT, Fargate, RDS, ElastiCache).

## Architecture
```
Developer push -> GitHub Actions: pytest, eslint/tsc, gitleaks, SonarCloud, terraform validate
   -> OIDC login to AWS -> build images -> Trivy scan -> push to ECR (tag = git SHA)
   -> SSM Run Command on EC2 -> scripts/deploy.sh:
        pull images, Alembic migration, docker compose up -d, health check

Browser -> :80 Nginx -> /api/*  -> backend (FastAPI) -> Postgres, Redis, S3, Groq API
                     -> /       -> frontend (Next.js)
```

## Done

### Application (`backend/`)
| Item | Detail |
|---|---|
| Redis cache | Results cached 24 h by SHA-256 of the PDF (`app/cache.py`); saves Groq calls |
| Rate limiting | 10 requests/min per IP (`RATE_LIMIT_PER_MINUTE`), returns 429 |
| Postgres history | `analyses` table via SQLAlchemy (`app/db.py`); new `GET /history` endpoint |
| Alembic migrations | `alembic/versions/0001_create_analyses.py`; run before every rollout |
| S3 resume storage | Uploaded PDFs stored with SSE (`app/storage.py`) |
| Optional backends | Each is disabled when its env var (`DATABASE_URL`, `REDIS_URL`, `S3_BUCKET`) is unset, so local dev is unchanged; Redis failures fail open |
| Tests | `backend/tests/test_api.py` (health, validation, success, cache hit, rate limit; Groq mocked) |
| Dependencies | Added sqlalchemy, psycopg2-binary, alembic, redis, boto3; `requirements-dev.txt` for pytest |

### Runtime stack
- `nginx/nginx.conf`: reverse proxy on port 80 (`/api/` to backend with prefix stripped, `/` to frontend).
- `docker-compose.prod.yml` rewritten: pulls images from ECR, only Nginx is published, Postgres (volume) and Redis (64 MB cap) are internal.
- Prometheus, Grafana and node-exporter moved to the `monitoring` profile (off by default, bound to localhost) because of 1 GB RAM.
- `scripts/deploy.sh`: runs on the host; reads secrets from SSM, logs in to ECR, pulls, migrates, starts, health-checks. Rollback = run it with an older tag.
- Frontend is built with `NEXT_PUBLIC_BACKEND_URL=/api`.

### Infrastructure (`terraform/aws`)
| File | Resources |
|---|---|
| `ec2.tf` | Ubuntu 24.04 `t3.micro`, 30 GB encrypted gp3, IMDSv2 with hop limit 2 (containers can use the instance role), Elastic IP |
| `security_groups.tf` | Port 80 only; SSH removed (use SSM Session Manager) |
| `ecr.tf` | `resume-backend` and `resume-frontend`, immutable tags, scan on push, keep last 3 images (500 MB free limit) |
| `s3.tf` | Private encrypted resumes bucket, public access blocked, 7-day expiry |
| `ssm.tf` | SecureString parameters: `groq_api_key` (placeholder, set manually), generated `db_password` and `grafana_admin_password` |
| `iam.tf` | EC2 role: SSM core, ECR read, read `/resume-analyzer/*`, put to resumes bucket |
| `oidc.tf` | GitHub OIDC provider and CI role limited to `master` of the configured repo; ECR push and SSM SendCommand only |
| `budgets.tf` | $0.01 monthly budget, email on actual and forecasted overspend |
| `provider.tf` | Terraform >= 1.10, S3 remote backend (partial config, native lockfile, no DynamoDB) |
| `user_data.sh` | One-time bootstrap: 2 GB swap, Docker, AWS CLI v2, clone repo |
| `terraform/bootstrap` | Creates the versioned, encrypted S3 state bucket |

Removed: `ecs_fargate.tf.example`, SSH and monitoring-port ingress rules, Groq key passed through `user_data`.

### CI/CD (`.github/workflows/ci-cd.yml`)
- Jobs: backend pytest, frontend lint and `tsc`, gitleaks, SonarCloud (skipped without `SONAR_TOKEN`), terraform fmt and validate.
- On `master`: build, Trivy (fails on fixable CRITICAL), push to ECR (skips if tag already exists), deploy via SSM, print deploy output.
- Manual rollback through `workflow_dispatch` with `rollback_tag`.
- Support files: `sonar-project.properties`, `.gitattributes` (LF for `*.sh`), `.gitignore` updated, `terraform.tfstate*` untracked.

### Docs
- `DEPLOY.md`: setup and operations runbook.

## Deviations from the original brief
1. SSM Run Command instead of SSH for deploys (no open port 22, no key in GitHub).
2. Groq key is set once via `aws ssm put-parameter`, not through Terraform.
3. S3-native state locking instead of a DynamoDB lock table.

## Remaining (your steps)
1. Rotate the Groq key (the old committed `terraform.tfstate` may have exposed it).
2. `terraform/bootstrap`: `init` and `apply`, note the state bucket.
3. `terraform/aws`: fill `backend.hcl` and `terraform.tfvars`, then `init -backend-config=backend.hcl` and `apply`.
4. `aws ssm put-parameter` with the new Groq key.
5. Confirm the Budgets email subscription.
6. Add GitHub repo variables `AWS_REGION`, `AWS_ROLE_ARN`, `EC2_INSTANCE_ID` (optional secret `SONAR_TOKEN`).
7. Commit and push to `master`; check the Actions run and open `app_url`.

## Known risks and open items
- Nothing has been executed yet; expect small fixes on the first `terraform validate`, `pytest` or deploy run.
- Free-tier eligibility depends on the account's creation date (credit-based plan vs 12-month hours).
- The frontend image includes full `node_modules` and may be large; if ECR exceeds 500 MB, switch to Next.js standalone output.
- 1 GB RAM is tight; monitoring is off by default and swap is enabled.
- Not built: frontend history view, moving the legacy `Jenkinsfile` to `docs/legacy/`, integration tests against real Postgres and Redis.
- Run `terraform destroy` in `terraform/aws` when not demoing.
