# infra-core — Sprint Evidence

Evidence captured during the July 27, 2026 sprint: 79 AWS resources, live ALB HTTP 200, Ansible 50 tasks, GuardDuty + Security Hub + AWS Config enabled.

---

## What to Screenshot and Save Here

Place screenshots directly in this folder with the filenames below so the Dev.to article and portfolio can reference them by name.

| File | What to Capture |
|---|---|
| `01-tf-plan-summary.png` | `terraform plan` output showing resource count (should be ~79) |
| `02-tf-apply-complete.png` | `terraform apply` final line — "Apply complete! Resources: 79 added" |
| `03-pipeline-green.png` | GitHub Actions run showing all steps green (tf-apply workflow) |
| `04-alb-health-check.png` | `curl -i http://<alb-dns>/health` → HTTP 200 + `{"status":"ok","service":"infra-core"}` |
| `05-prometheus-targets.png` | ALB targets page in AWS console showing healthy EC2 targets |
| `06-cloudwatch-dashboard.png` | CloudWatch dashboard showing EC2 CPU, RDS connections, ALB 5XX |
| `07-ssm-session.png` | Active SSM Session Manager shell on a private EC2 instance (no port 22) |
| `08-ansible-run.png` | Ansible playbook output — all 50 tasks `ok` or `changed`, 0 failed |
| `09-ecr-repository.png` | ECR repository with pushed Docker image |
| `10-guardduty-enabled.png` | GuardDuty detector showing ENABLED status |
| `11-security-hub-enabled.png` | Security Hub showing CIS AWS Foundations Benchmark active |
| `12-rds-private.png` | RDS instance details — Publicly Accessible: No, VPC: infra-core-dev |
| `13-ssm-parameters.png` | SSM Parameter Store showing `/infra-core/dev/db_host` etc. as SecureString |
| `14-vpc-subnets.png` | VPC console showing public (10.0.1/2.0/24) and private (10.0.10/11.0/24) subnets |
| `15-destroy-complete.png` | `terraform destroy` final line — "Destroy complete! Resources: 79 destroyed" |

---

## Sprint Results Summary

| Check | Result |
|---|---|
| Terraform resources | 79 created, 79 destroyed cleanly |
| Ansible tasks | 50 tasks, 0 failed |
| ALB health check | HTTP 200 — `{"status":"ok","service":"infra-core"}` |
| SSM access | Interactive shell on private EC2, zero SSH port open |
| GuardDuty | Enabled — ML-based threat detection active |
| Security Hub | Enabled — CIS Benchmark scoring active |
| AWS Config | Enabled — compliance rules active |
| CI/CD pipeline | All stages green (Checkov, plan, apply, smoke test) |
| Sprint cost | ~$4–6 for full 2-day sprint |

---

*Add screenshots from the next sprint here.*
