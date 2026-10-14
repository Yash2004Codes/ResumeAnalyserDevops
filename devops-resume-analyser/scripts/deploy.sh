#!/bin/bash
# Runs ON the EC2 host (invoked by CI through SSM Run Command).
# Usage: deploy.sh <image-tag>      Rollback = run again with an older tag.
set -euo pipefail

IMAGE_TAG="${1:?usage: deploy.sh <image-tag>}"
source /etc/resume-analyzer.env   # AWS_REGION, ECR_REGISTRY, S3_BUCKET

APP_DIR=/opt/devops-resume-analyser
cd "$APP_DIR"
COMPOSE="docker compose -f docker-compose.prod.yml"

param() {
  aws ssm get-parameter --region "$AWS_REGION" --with-decryption \
    --name "/resume-analyzer/$1" --query Parameter.Value --output text
}

GROQ_API_KEY="$(param groq_api_key)"
if [ "$GROQ_API_KEY" = "REPLACE_ME" ]; then
  echo "SSM parameter /resume-analyzer/groq_api_key is still the placeholder" >&2
  exit 1
fi

umask 077
cat > .env <<ENV
ECR_REGISTRY=$ECR_REGISTRY
IMAGE_TAG=$IMAGE_TAG
GROQ_API_KEY=$GROQ_API_KEY
POSTGRES_PASSWORD=$(param db_password)
GRAFANA_ADMIN_PASSWORD=$(param grafana_admin_password)
S3_BUCKET=$S3_BUCKET
AWS_DEFAULT_REGION=$AWS_REGION
CORS_ORIGINS=*
ENV

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

$COMPOSE pull backend frontend
$COMPOSE up -d postgres redis
$COMPOSE run --rm backend alembic upgrade head   # migrations before rollout
$COMPOSE up -d --remove-orphans

echo "Waiting for the app to become healthy..."
for i in $(seq 1 30); do
  if curl -fsS http://localhost/api/health >/dev/null && curl -fsS http://localhost/ >/dev/null; then
    echo "Deployed $IMAGE_TAG"
    docker image prune -f >/dev/null
    exit 0
  fi
  sleep 5
done

echo "Health check failed for $IMAGE_TAG" >&2
$COMPOSE ps >&2
exit 1
