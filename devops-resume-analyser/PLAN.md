# PLAN: Production-Grade DevOps Pipeline on AWS

Project: **DevOps Resume Analyser** (Next.js 16 + FastAPI + Groq LLM)
Goal: an industry-standard CI/CD pipeline and AWS deployment, where every AWS service has a real job in the app, with trade-offs documented and cost controlled.

Status: CTO-reviewed (conditional approve). Last updated: 2026-10-14.

---

## 1. Current state (what is done)

| Area | Status |
|---|---|
| App | Working: PDF upload, text extraction (`pdfplumber`), Groq `llama-3.3-70b` scoring. Stateless, no storage. |
| Containers | Dockerfiles (frontend, backend), `docker-compose.yml`, `docker-compose.prod.yml`, health checks |
| CI | Jenkins: webhook, SonarQube scan, Quality Gate, Docker build, Selenium homepage test |
| Monitoring | Prometheus, Grafana (dashboard as code), Node Exporter, FastAPI `/metrics` |
| IaC | Local Terraform (Jenkins and Sonar in Docker). `terraform/aws/`: VPC, public subnet, IGW, SG, one EC2 and an EIP, SSM role |
| Docs | README, arch.md, INTERVIEW_QA.md, report.md |

## 2. Gaps to close

1. The deploy stage is a stub (`echo "Deployment completed"`), so there is no real CD.
2. There are no unit or integration tests, only one Selenium homepage test.
3. There is no dependency, image or secret scanning.
4. Everything runs on one EC2 instance: no managed DB, no object storage, no load balancer, no TLS, no autoscaling.
5. Secrets are weak: the Groq key goes through Terraform `user_data` (so it sits in state); Grafana is `admin/admin`.
6. `terraform.tfstate` is local and committed. A remote backend with locking is needed.
7. There is no image registry. Images are built on the server instead of built once and promoted.
8. There are no environments and no rollback strategy.
9. There is no cloud observability (logs, alarms, SLOs).
10. Resume data is PII with no retention, encryption or logging policy.

## 3. Target architecture

```
Dev -> GitHub PR -> CI: lint, unit + integration tests, Sonar, Trivy, gitleaks
                  -> build image once, tag with git SHA, push to ECR
                  -> CD: deploy to STAGING (ECS Fargate)
                  -> run DB migration task, smoke/E2E tests
                  -> manual approval
                  -> deploy to PROD (rolling, circuit-breaker auto-rollback)
```

```
Users -> Route 53 -> (CloudFront optional) -> ALB (ACM TLS, optional WAF managed rules)
                          |
                 ECS Fargate (private subnets)
                  +- frontend service (Next.js)
                  +- backend service (FastAPI)
                          |
     +--------------------+--------------------+---------------+
     |                    |                    |               |
  S3 (KMS)          RDS PostgreSQL      ElastiCache Redis   Secrets Manager
  resume files      analysis history    result cache,       (Groq key, DB creds)
  lifecycle expiry  users               rate limiting
                          |
                  CloudWatch Logs/Alarms -> SNS    AWS Budgets
```

### AWS services and the reason each exists
| Service | Job in this project |
|---|---|
| VPC (public/private subnets, VPC endpoints) | Network isolation; app and data tiers are not internet-facing |
| ALB + ACM (+ Route 53) | HTTPS entry point, health-checked routing |
| ECR | Immutable, SHA-tagged images with scan-on-push; built once, promoted |
| ECS Fargate | Runs containers without managing servers (chosen over EKS: one small service does not justify the operational cost) |
| S3 (SSE-KMS, block public access) | Stores uploaded resumes; presigned URLs; lifecycle rule expires objects (PII retention) |
| RDS PostgreSQL | Analysis history, users; migrations with Alembic |
| ElastiCache Redis | Cache results by file hash (saves Groq calls); rate limiting |
| Secrets Manager | Groq key and DB credentials, injected into tasks at runtime |
| IAM (least privilege, task roles) + GitHub OIDC | No long-lived keys anywhere, including CI |
| CloudWatch (Logs, Alarms, Dashboards) + SNS | SLO-based alerting and notifications |
| AWS Budgets | Cost alerts |
| Terraform + S3/DynamoDB remote state | Reproducible, locked, reviewable infrastructure |
| WAF (managed rules only) | Optional baseline protection |

Explicitly **cut**: SQS and worker, GuardDuty, EKS, a third (dev) environment. Reason: not justified by a real requirement. Revisit if requirements change.

## 4. Key design decisions (to document as ADRs)

1. **GitHub Actions is the primary pipeline.** The Jenkinsfile moves to `docs/legacy/` as a reference. The Sonar and Selenium stages port over.
2. **Fargate over EKS and over plain EC2.**
3. **Two environments**, staging and prod, using shared Terraform modules and an `envs/` folder. Staging can be destroyed on demand.
4. **Build once, promote the same image digest** from staging to prod.
5. **Migrations** run as a one-off ECS task before rollout and must be backward-compatible so rollback is safe.
6. **PII handling:** KMS encryption, presigned URLs, lifecycle expiry, no resume text in logs, documented retention.
7. **Cost controls:** single NAT or VPC endpoints for staging, `db.t4g.micro` single-AZ in staging, a destroy workflow, Budgets alerts.

## 5. Phases

### Phase 1: Foundation
- [ ] Remove `terraform.tfstate*` from git; add to `.gitignore`; rotate any exposed secrets
- [ ] Bootstrap stack: S3 state bucket + DynamoDB lock table
- [ ] Restructure Terraform into modules (`network`, `ecr`, `ecs`, `rds`, `s3`, `redis`, `iam`, `monitoring`) with `envs/staging` and `envs/prod`
- [ ] GitHub OIDC role for CI

### Phase 2: Application features and tests
- [ ] Backend: S3 upload, RDS history (SQLAlchemy + Alembic), Redis cache, rate limiting
- [ ] Frontend: history view
- [ ] Unit tests (pytest, Groq mocked), integration tests (Postgres/Redis service containers), coverage gate
- [ ] Remove resume text from logs; structured JSON logging

### Phase 3: CI (GitHub Actions)
- [ ] Lint (ruff, eslint, tsc), unit and integration tests, coverage gate
- [ ] SonarQube/SonarCloud + Quality Gate
- [ ] Trivy (filesystem and image), gitleaks, dependency audit
- [ ] Build images, tag with git SHA, push to ECR
- [ ] Terraform fmt/validate/plan on PR (plan posted as a comment)

### Phase 4: AWS infrastructure
- [ ] VPC with public/private subnets and VPC endpoints
- [ ] ALB, ACM, Route 53 (or ALB DNS if there is no domain)
- [ ] ECS cluster and services, task roles, Secrets Manager injection
- [ ] RDS, S3 (KMS), ElastiCache

### Phase 5: CD
- [ ] Deploy to staging, run migration task, smoke/E2E tests (Selenium port or Playwright)
- [ ] Manual approval (GitHub Environments), deploy to prod
- [ ] ECS deployment circuit breaker and automatic rollback; documented manual rollback

### Phase 6: Observability and hardening
- [ ] CloudWatch dashboards; SLOs (for example 99% `/analyze` success, p95 latency target) with alarms to SNS
- [ ] AWS Budgets alerts
- [ ] Optional: WAF managed rules; Prometheus/Grafana on AWS
- [ ] Runbook: deploy, rollback, incident, destroy

### Phase 7: Showcase
- [ ] Architecture diagram and ADRs in `docs/`
- [ ] README: pipeline diagram, cost table, how to deploy and destroy
- [ ] Short demo: push, CI, staging, approval, prod, rollback
- [ ] Update INTERVIEW_QA.md

## 6. Priorities

| Priority | Items |
|---|---|
| Must | Remote state, modules, Secrets Manager, OIDC, ECR, Fargate + ALB, GitHub Actions CI/CD with staging to prod and rollback, S3 (KMS), RDS + migrations, unit and integration tests |
| Should | Redis cache, HTTPS with a domain, SLO alarms, Trivy and gitleaks, cost controls |
| Could | WAF, Prometheus/Grafana on AWS |
| Cut | SQS/worker, GuardDuty, EKS, dev environment |

## 7. Estimated cost (us-east-1, approximate, running 24/7)

| Item | ~USD/month |
|---|---|
| NAT gateway (1) | 32 |
| ALB | 18 |
| Fargate (2 small tasks) | 15-30 |
| RDS db.t4g.micro single-AZ | 13 |
| ElastiCache cache.t4g.micro | 12 |
| S3, ECR, CloudWatch, Secrets Manager | 5-10 |
| **Total (one environment)** | **~95-115** |

Mitigation: keep staging destroyed except during demos or releases, use VPC endpoints instead of NAT where possible, and set Budgets alerts. Estimates must be re-checked against current AWS pricing before apply.

## 8. Open questions

1. AWS account available, and the acceptable monthly spend?
2. Own a domain (Route 53), or use the ALB DNS name?
3. Confirm: primary pipeline is GitHub Actions and Jenkins moves to legacy docs.
4. Confirm: adding a database and S3 storage to the app is acceptable.

## 9. Definition of done

- Push to a branch triggers CI with tests, scans and an image in ECR.
- Merge deploys to staging automatically; smoke tests pass.
- Approval promotes the same image to prod; a bad deploy auto-rolls back.
- No secrets in git, in Terraform state or in CI; no long-lived AWS keys.
- One command creates the environment and one command destroys it.
- Architecture, trade-offs, runbook and costs are documented.

---

## 10. Is this project impressive to a CTO? An honest assessment

### Short answer
**Today: no, not really.** After this plan is executed well: **yes, for a junior to mid-level DevOps/Cloud role, and noticeably above the typical portfolio project.** It will not impress a CTO as "production experience", and it should not be presented as such.

### Why it is NOT impressive today
- The "AWS deployment" is one EC2 instance running docker-compose. That is a laptop setup moved to a server, and a CTO has seen it many times.
- The deploy stage only prints a message. The pipeline stops at CI and never delivers anything.
- The application is a thin wrapper: upload a PDF, call a third-party LLM, show a score. There is no data, no users and no real workload. The business logic is a prompt.
- The Jenkins/SonarQube/Prometheus/Grafana stack is the standard tutorial stack. Much of it is also run on a local machine.
- One Selenium test that checks the homepage loads does not demonstrate a testing strategy.
- Secrets in Terraform state and a committed `terraform.tfstate` are the kind of mistakes a CTO spots in minutes. Right now they count against you.

### What a CTO actually evaluates (and the honest score after the plan)
| What a CTO looks for | Today | After the plan |
|---|---|---|
| Security by default (no static keys, no secrets in git, least privilege, PII handling) | Weak | Strong, and the most differentiating part |
| Reproducible infrastructure (modules, remote state, one-command create/destroy) | Partial | Strong |
| Safe delivery (build once, promote, approval, auto-rollback, migrations) | Missing | Strong |
| Judgment (right-sized choices, trade-offs written down, things deliberately cut) | Not shown | Strong if the ADRs are real |
| Cost awareness | Not shown | Good |
| Operating it (SLOs, alarms, runbook) | Basic dashboards | Good, but untested under real load |
| Scale, reliability under real traffic, on-call experience, team workflow | None | **Still none** |

### What will genuinely stand out
1. **Judgment over tool count.** Choosing Fargate over EKS and cutting SQS/GuardDuty, with written reasons, shows more maturity than a long list of services.
2. **OIDC, no long-lived keys, Secrets Manager, KMS-encrypted resume storage with expiry.** Most candidates skip all of this.
3. **A rollback you have actually demonstrated**, including a backward-compatible migration case.
4. **A cost table and a destroy button.** It shows you think about the bill.
5. **A working live demo** beats any diagram.

### What will NOT impress, and limits to be upfront about
- This is a single-developer project with synthetic traffic. It proves you can design and build a pipeline, not that you have run one for a team, handled an incident, or scaled a system. Do not claim otherwise.
- Using many AWS services is not a goal. A CTO will ask "why is Redis here?" If the answer is weak (for example "caching Groq results" with no measured hit rate), it counts against you. Only keep a service if you can justify it with the app's behavior.
- The application itself stays simple. The value is in the delivery and operations around it, so present it that way: "the app is a vehicle for the platform work."
- Over-engineering is a risk in the other direction. If the demo is slow, flaky or not running when someone clicks the link, that outweighs all the architecture.
- Interview claims must match what exists in the repo. Anything in the diagram that is not built and working should be marked "planned".

### How to make it land
- Lead with a one-page README: problem, diagram, the 3 or 4 key decisions and their trade-offs, cost, and a link to the live demo or a recorded run.
- Be able to explain every line. Assume the CTO picks one component at random and asks why.
- Show failure, not just success: a failed quality gate blocking a deploy, an auto-rollback, an alarm firing.
- Measure something real (cache hit rate, p95 latency, deploy time) and quote the number.

---

## 11. Impressiveness in an offline (in-person) interview

### Honest verdict
**Yes, it works well in a face-to-face interview, more than it works as a document.** In person, the interviewer cannot skim a README; they ask questions and watch you answer. A project you built and can explain under questioning is worth more than a bigger one you cannot. For a fresher or junior DevOps/Cloud role it is above average. For a senior role it is not enough on its own.

### Why it works in the room
- **It gives the interviewer many things to ask about.** CI/CD, Docker, Terraform, networking, IAM, databases, monitoring and security each lead to a follow-up. A strong project gives you 30 to 45 minutes of conversation on your own ground.
- **Few candidates have a pipeline that really delivers.** Most projects stop at "I wrote a Dockerfile". Showing push, tests, scan, image, staging, approval, prod and rollback puts you in a small group.
- **Trade-off answers are what interviewers remember.** "I chose Fargate over EKS because one small service did not justify cluster operations" lands better than any tool list.
- **Failure stories are credible.** "My Quality Gate blocked a deploy", "the Docker-in-Docker volume mount broke the tests and I fixed it" (that is already in your git history) show real hands-on work.

### Where it can hurt you
- **If you cannot explain a part, it counts against you.** The interviewer will pick one component at random. If it is in your resume, you must be able to explain it: why it is there, how it works, what happens if it fails. Cut anything you cannot defend.
- **They will test depth with "what if" questions.** Examples: "What if the migration fails halfway?", "Why is the DB in a private subnet?", "How does the container get the secret?", "What happens when the ALB health check fails?", "What does this IAM policy allow?" Prepare these.
- **AI-assisted work is easy to expose.** If a large part was generated, an interviewer who asks you to modify or debug something live will notice. You should be able to change a Terraform variable, read a pipeline log or fix a broken step on the spot.
- **A project that is not running is a weak demo.** Do not rely on live AWS during the interview: the infrastructure may be destroyed to save cost, and venue Wi-Fi is unreliable. Have a recorded run and screenshots ready, plus the ability to bring the environment up.
- **Overclaiming gets caught.** Say "I built this as a personal project to learn production practices", not "I run production systems". Interviewers respect honesty and punish bluffing.

### How the project maps to common interview questions
| Likely question | Where this project answers it |
|---|---|
| Explain your CI/CD pipeline end to end | Section 3 flow: PR, tests, scans, ECR, staging, approval, prod |
| How do you handle secrets? | OIDC, Secrets Manager, no keys in git or state |
| How do you roll back? | ECS circuit breaker, backward-compatible migrations |
| Docker vs. VM, why Fargate? | ADR 2 |
| What is Terraform state, and why remote? | S3 + DynamoDB locking, and the committed-state mistake you fixed |
| How would you monitor it? | SLOs, CloudWatch alarms, Prometheus/Grafana |
| How would you cut costs? | Cost table, destroy workflow, Budgets |
| What would you do differently at scale? | Honest answer: multi-AZ, autoscaling, blue/green, EKS if services grow |

### Preparation checklist for the interview
- [ ] One-page architecture diagram, printed or on your phone, which you can redraw from memory on a whiteboard
- [ ] A 2-minute pitch: problem, architecture, the 3 key decisions, one failure you hit and fixed
- [ ] A recorded demo (3 to 5 minutes) and screenshots as backup if live AWS is unavailable
- [ ] Be able to open the repo and walk through `Jenkinsfile`/workflow, a Terraform module and the Dockerfile without notes
- [ ] 15 to 20 "what if" questions with answers in `INTERVIEW_QA.md`
- [ ] A list of what is NOT built and what you would add next (shows honesty and awareness)
- [ ] Resume lines that match the repo exactly, each with a number (deploy time, coverage, p95 latency, monthly cost)

### Bottom line
In an offline interview the project is a strong **conversation starter**, and its value is set by how well you can talk about it. Build it in the order of the plan, keep the scope you can defend, and practise explaining it out loud. A smaller project you fully understand will beat a larger one you cannot explain.
