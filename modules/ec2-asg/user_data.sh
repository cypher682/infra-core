#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# EC2 Bootstrap — runs once on first launch
# Ansible handles the full configuration after this
# ─────────────────────────────────────────────

PROJECT="${project}"
ENVIRONMENT="${environment}"
SSM_NAMESPACE="${ssm_namespace}"

echo "=== Bootstrap starting for $PROJECT/$ENVIRONMENT ==="

# Install and enable SSM Agent first so the instance becomes manageable
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl restart amazon-ssm-agent

# Install required packages. Amazon Linux 2023 ships curl-minimal; installing curl
# can conflict during cloud-init, and curl-minimal already provides the curl binary.
dnf install -y \
  docker \
  nginx \
  python3 \
  python3-pip \
  jq \
  wget \
  git \
  htop \
  unzip \
  amazon-cloudwatch-agent

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Install AWS CLI v2
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# Create app user (non-root)
useradd -m -s /bin/bash appuser
usermod -aG docker appuser

# Create app directory
mkdir -p /opt/app
chown appuser:appuser /opt/app

# Simple health check endpoint via nginx (before Ansible configures fully)
cat > /etc/nginx/conf.d/health.conf << 'EOF'
server {
    listen 80;
    location /health {
        return 200 '{"status":"ok","service":"infra-core"}';
        add_header Content-Type application/json;
    }
}
EOF

# Start nginx for ALB health checks
systemctl enable nginx
systemctl start nginx

echo "=== Bootstrap complete ==="
