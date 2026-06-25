# infra-core

[![Terraform](https://img.shields.io/badge/Terraform-1.7-purple?style=flat-square&logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-us--east--1-orange?style=flat-square&logo=amazon-aws)](https://aws.amazon.com/)
[![Ansible](https://img.shields.io/badge/Ansible-CIS--Hardened-red?style=flat-square&logo=ansible)](https://www.ansible.com/)
[![CI](https://github.com/cypher682/infra-core/actions/workflows/tf-plan.yml/badge.svg)](https://github.com/cypher682/infra-core/actions/workflows/tf-plan.yml)

Production-grade AWS infrastructure provisioned with Terraform and hardened with Ansible. Multi-environment (dev + staging), fully modular IaC, CIS-hardened EC2, and CloudWatch observability end-to-end.

---

## Architecture

```
[ Internet ]
      │ HTTP :80
      ▼
[ ALB — public subnets, 2 AZs ]
      │
      ▼
[ EC2 Auto Scaling Group — private subnets, 2 AZs ]
      │ :5432
      ▼
[ RDS PostgreSQL — private subnets ]

[ SSM Session Manager ] ──► EC2  (no SSH port, no bastion)
[ SSM Parameter Store ] ──► app reads secrets at runtime
[ ECR ] ──► Docker images pulled by Ansible app-deploy role
[ S3 ] ──► VPC flow logs + application assets
[ CloudWatch ] ──► metrics, log groups, alarms, SNS email
[ GuardDuty ] ──► Threat detection
[ Security Hub ] ──► Posture management and compliance
[ AWS Config ] ──► Automated resource compliance rules
[ GitHub Actions OIDC ] ──► Terraform CI/CD (no static keys)
```

---

## Stack

| Layer | Technology |
|---|---|
| IaC | Terraform 1.7 — modular, multi-environment |
| Config management | Ansible + CIS Amazon Linux 2023 hardening |
| Compute | EC2 ASG (t3.micro) + ALB |
| Database | RDS PostgreSQL 15 (db.t3.micro) |
| Container registry | Amazon ECR |
| Secrets | SSM Parameter Store (SecureString + KMS) |
| Observability | CloudWatch metrics, log groups, alarms, dashboard |
| CI/CD | GitHub Actions + OIDC — no static AWS keys |
| Security | GuardDuty, Security Hub, AWS Config, IMDSv2, fail2ban, auditd, Checkov |

---

## Repository Structure

```
infra-core/
├── modules/
│   ├── vpc/          # VPC, subnets, SGs, NAT GW, VPC flow logs
│   ├── iam/          # GitHub OIDC role, EC2 instance profile
│   ├── s3/           # App assets + flow logs buckets (encrypted, private)
│   ├── ssm/          # Parameter Store secrets namespace
│   ├── rds/          # PostgreSQL, subnet group, parameter group
│   ├── alb/          # ALB, target group, HTTP listener
│   ├── ec2-asg/      # Launch template, ASG, CPU scaling policies
│   ├── ecr/          # ECR repository + lifecycle policy
│   └── cloudwatch/   # Alarms, log groups, SNS topic, dashboard
├── environments/
│   ├── dev/          # CIDR 10.0.0.0/16
│   └── staging/      # CIDR 10.1.0.0/16
├── ansible/
│   ├── site.yml
│   ├── inventory/    # Dynamic AWS SSM inventory (no static IPs)
│   └── roles/
│       ├── common/
│       ├── hardening/    # CIS AL2023 baseline
│       ├── docker/
│       ├── nginx/
│       ├── monitoring/   # CloudWatch agent
│       └── app-deploy/   # Pull from ECR + run container
└── .github/workflows/
    ├── tf-plan.yml   # PR: plan + Checkov + comment on PR
    └── tf-apply.yml  # Merge: apply + ALB smoke test
```

---

## Quick Start

### Prerequisites

- Terraform >= 1.6
- AWS CLI configured
- Ansible + `amazon.aws` collection (WSL2 for Windows)

### 1. Set credentials

```bash
export TF_VAR_db_password="your-password"
export TF_VAR_db_username="appuser"
export AWS_ACCOUNT_ID="123456789012"
```

### 2. Update tfvars

Edit `environments/dev/terraform.tfvars`:

```hcl
aws_account_id = "123456789012"
```

### 3. Init, plan, apply

```bash
make init ENV=dev
make plan ENV=dev
make apply ENV=dev
```

### 4. Harden with Ansible (WSL2)

```bash
make ansible ENV=dev
```

### 5. Smoke test

```bash
make smoke ENV=dev
# → {"status":"ok","service":"infra-core"}
```

### 6. Access EC2 (no SSH port open)

```bash
make ssm-session ENV=dev
```

### 7. Teardown

```bash
make destroy ENV=dev
```

---

## GitHub Actions Setup

Add these secrets to the repository:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | `terraform output github_actions_role_arn` |
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |
| `DB_PASSWORD` | RDS master password |
| `DB_USERNAME` | RDS master username |

OIDC is pre-configured — no `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` needed.

---

## Security Controls

| Control | Implementation |
|---|---|
| Threat Detection | GuardDuty (intelligent threat protection) |
| Posture Management | Security Hub (continuous CIS foundations benchmark) |
| Automated Compliance | AWS Config (managed rules for SSH, S3, EBS encryption) |
| No public RDS | Private subnet only, `publicly_accessible = false` |
| No SSH ports | SSM Session Manager — no bastion, no key pairs |
| IMDSv2 enforced | `http_tokens = required` in launch template |
| Encrypted at rest | RDS, EBS, S3 — all AES-256 |
| Secrets at runtime | SSM SecureString — never in code or Terraform state |
| Least privilege IAM | Scoped per-service roles, no AdministratorAccess |
| IaC security scan | Checkov on every PR, blocks merge on failure |
| CIS hardening | fail2ban, auditd, root SSH disabled, sysctl tuning |
| VPC flow logs | ALL traffic → S3, 30-day retention |

---

## Cost Model (Sprint)

| Resource | Rate | 2-day total |
|---|---|---|
| NAT Gateway | $0.045/hr | ~$2.20 |
| ALB | $0.008/hr | ~$0.40 |
| EC2 t3.micro | $0.0104/hr | ~$0.50 |
| RDS db.t3.micro | $0.017/hr | ~$0.82 |
| S3 + CloudWatch | minimal | ~$0.10 |
| **Total** | | **~$4–6** |

Sprint model: provision → capture evidence → destroy. No idle cost.

---

## Evidence

See `docs/` for:
- Architecture diagram
- Terraform plan output
- Checkov scan results
- GitHub Actions pipeline screenshots
- CloudWatch dashboard screenshot
- Ansible playbook run output
- SSM Session Manager screenshot

---

## Lessons Learned

- **IMDSv2 breaks `curl http://169.254.169.254`** in user data — fix: use `curl -H "X-aws-ec2-metadata-token: $TOKEN"` or query via instance profile directly
- **NAT Gateway is the biggest cost line** — single NAT is right for dev/staging; never multi-AZ NAT in non-prod
- **SSM Parameter Store beats Secrets Manager for cost** — $0 standard vs $0.40/secret/month
- **Checkov caught a missing `block_public_acls`** on the flow logs bucket before apply

---

*Built by [cypher682](https://github.com/cypher682) — part of the 2026 portfolio sprint*
