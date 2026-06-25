# ─────────────────────────────────────────────
# infra-core Makefile
# Usage: make <target> ENV=dev|staging
# Default: ENV=dev
# ─────────────────────────────────────────────

ENV        ?= dev
TF_DIR     := environments/$(ENV)
ANSIBLE_DIR := ansible

.PHONY: help init validate plan apply destroy lint ansible smoke cost-estimate

help: ## Show all available targets
	@echo ""
	@echo "infra-core — available targets"
	@echo "================================"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "ENV defaults to 'dev'. Override: make apply ENV=staging"
	@echo ""

init: ## terraform init in the target environment
	@echo "→ Initialising Terraform for ENV=$(ENV)"
	cd $(TF_DIR) && terraform init

validate: ## terraform validate
	@echo "→ Validating Terraform for ENV=$(ENV)"
	cd $(TF_DIR) && terraform validate

lint: ## Run tflint + checkov security scan
	@echo "→ Running tflint..."
	tflint --recursive || true
	@echo "→ Running Checkov IaC security scan..."
	checkov -d . --framework terraform --compact --quiet

plan: ## terraform plan (requires TF_VAR_db_password and TF_VAR_db_username env vars)
	@echo "→ Planning Terraform for ENV=$(ENV)"
	@[ -n "$(TF_VAR_db_password)" ] || (echo "ERROR: TF_VAR_db_password not set. Export it first." && exit 1)
	@[ -n "$(TF_VAR_db_username)" ] || (echo "ERROR: TF_VAR_db_username not set. Export it first." && exit 1)
	cd $(TF_DIR) && terraform plan \
		-var="aws_account_id=$(AWS_ACCOUNT_ID)" \
		-out=tfplan

apply: ## terraform apply (uses saved plan or replans)
	@echo "→ Applying Terraform for ENV=$(ENV)"
	@[ -n "$(TF_VAR_db_password)" ] || (echo "ERROR: TF_VAR_db_password not set." && exit 1)
	@[ -n "$(TF_VAR_db_username)" ] || (echo "ERROR: TF_VAR_db_username not set." && exit 1)
	cd $(TF_DIR) && terraform apply \
		-var="aws_account_id=$(AWS_ACCOUNT_ID)" \
		-auto-approve

destroy: ## terraform destroy — TEARS DOWN ALL RESOURCES
	@echo "⚠  WARNING: This will destroy all $(ENV) infrastructure."
	@read -p "Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || exit 1
	cd $(TF_DIR) && terraform destroy \
		-var="aws_account_id=$(AWS_ACCOUNT_ID)" \
		-var="db_password=$(TF_VAR_db_password)" \
		-var="db_username=$(TF_VAR_db_username)" \
		-auto-approve

output: ## Print terraform outputs
	cd $(TF_DIR) && terraform output

ansible: ## Run full Ansible hardening playbook against ENV
	@echo "→ Running Ansible playbook for ENV=$(ENV)"
	@echo "   Run this from WSL2 Ubuntu"
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml \
		-i inventory/aws_ssm.yml \
		--extra-vars "env=$(ENV)" \
		-v

smoke: ## Curl the ALB health endpoint
	@echo "→ Smoke testing ALB for ENV=$(ENV)"
	@ALB_DNS=$$(cd $(TF_DIR) && terraform output -raw alb_dns_name) && \
		echo "Testing http://$$ALB_DNS/health" && \
		curl -sf "http://$$ALB_DNS/health" | python3 -m json.tool

ssm-session: ## Open SSM Session Manager shell on an app instance
	@INSTANCE_ID=$$(aws ec2 describe-instances --filters "Name=tag:Role,Values=app" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text --region us-east-1) && \
		echo "Connecting to $$INSTANCE_ID" && \
		aws ssm start-session --target $$INSTANCE_ID --region us-east-1

cost-estimate: ## Estimate monthly cost using infracost (requires infracost CLI)
	@echo "→ Estimating cost for ENV=$(ENV)"
	infracost breakdown --path $(TF_DIR) --format table
