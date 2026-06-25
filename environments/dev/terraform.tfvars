# ─────────────────────────────────────────────
# Dev Environment — non-sensitive values only
# NEVER put db_password here — use:
#   export TF_VAR_db_password="yourpassword"
#   export TF_VAR_db_username="youruser"
# ─────────────────────────────────────────────

aws_region     = "us-east-1"
aws_account_id = "YOUR_AWS_ACCOUNT_ID" # Replace before apply
github_org     = "cypher682"
github_repo    = "infra-core"
alert_email    = "suleiman.abdulrahman.dev@gmail.com"
