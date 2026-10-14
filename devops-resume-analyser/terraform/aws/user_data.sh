#!/bin/bash
# One-time host bootstrap. Application rollouts are done by scripts/deploy.sh (via CI + SSM).
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive

# 2 GB swap: a t3.micro has only 1 GB RAM
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

apt-get update -y
apt-get install -y docker.io docker-compose-v2 git curl unzip jq
systemctl enable --now docker

# AWS CLI v2
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

cat > /etc/resume-analyzer.env <<ENV
AWS_REGION=${aws_region}
ECR_REGISTRY=${ecr_registry}
S3_BUCKET=${s3_bucket}
ENV

APP_DIR=/opt/devops-resume-analyser
rm -rf "$APP_DIR"
git clone -b ${repo_branch} ${repo_url} "$APP_DIR"
chmod +x "$APP_DIR/scripts/deploy.sh"

echo "Bootstrap complete. Set the Groq key in SSM, then let CI deploy."
