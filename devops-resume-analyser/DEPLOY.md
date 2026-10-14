# Deploy runbook (free-tier stack)

Flow: push to `master` -> GitHub Actions (pytest, eslint/tsc, gitleaks, SonarCloud, terraform validate)
-> OIDC login -> build + Trivy scan + push to ECR (tag = git SHA) -> SSM Run Command runs `scripts/deploy.sh` on the EC2
(pull, Alembic migration, `docker compose up -d`, health check).

## One-time setup
1. `cd terraform/bootstrap && terraform init && terraform apply` -> note `state_bucket`.
2. `cd ../aws`, copy `backend.hcl.example` -> `backend.hcl` (fill bucket) and `terraform.tfvars.example` -> `terraform.tfvars`.
3. `terraform init -backend-config=backend.hcl && terraform apply`
4. Set the real Groq key:
   `aws ssm put-parameter --name /resume-analyzer/groq_api_key --type SecureString --value "gsk_..." --overwrite`
5. GitHub repo -> Settings -> Variables: `AWS_REGION`, `AWS_ROLE_ARN` (output `github_ci_role_arn`), `EC2_INSTANCE_ID` (output `instance_id`).
   Optional secret `SONAR_TOKEN` (and edit `sonar-project.properties`).
6. Push to `master`. App is at the `app_url` output.

## Operations
- Shell: `aws ssm start-session --target <instance_id>` (no SSH port is open).
- Rollback: Actions -> CI/CD -> Run workflow -> `rollback_tag` = an older git SHA still in ECR (last 3 are kept).
- Monitoring (off by default, 1 GB RAM): on the host `cd /opt/devops-resume-analyser && docker compose -f docker-compose.prod.yml --profile monitoring up -d`, then use the `grafana_tunnel` output.
- Tear down: `terraform destroy` in `terraform/aws`.
