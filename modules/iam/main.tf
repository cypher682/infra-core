# ─────────────────────────────────────────────
# GitHub Actions OIDC Provider
# Allows GitHub Actions to assume AWS roles without static keys
# CIS: no long-lived credentials in CI/CD
# ─────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint — stable, verified against GitHub's cert chain
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.tags, {
    Name = "${var.project}-github-oidc-provider"
  })
}

# ─────────────────────────────────────────────
# GitHub Actions IAM Role
# Scoped to this repo and environment only
# ─────────────────────────────────────────────
data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Lock to specific repo — no other repo can assume this role
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project}-${var.environment}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-github-actions-role"
  })
}

# GitHub Actions permissions — scoped to what Terraform needs
# Principle: only what this project's Terraform actually touches
data "aws_iam_policy_document" "github_actions_permissions" {
  # EC2 + VPC + ALB
  statement {
    effect = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
    ]
    resources = ["*"]
  }

  # RDS
  statement {
    effect    = "Allow"
    actions   = ["rds:*"]
    resources = ["*"]
  }

  # S3 — scoped to project buckets only
  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.project}-*",
      "arn:aws:s3:::${var.project}-*/*"
    ]
  }

  # SSM Parameter Store — scoped to project namespace
  statement {
    effect  = "Allow"
    actions = ["ssm:*"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project}/*"
    ]
  }

  # IAM — limited to managing project roles only (no wildcard IAM)
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:ListRoles",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:PassRole",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
    ]
    resources = ["*"]
  }

  # CloudWatch
  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:*", "logs:*", "sns:*"]
    resources = ["*"]
  }

  # ACM (even if not using certs now — keeps plan clean)
  statement {
    effect    = "Allow"
    actions   = ["acm:*"]
    resources = ["*"]
  }

  # ECR — GitHub Actions pushes sample app image; EC2 pulls it via Ansible app-deploy
  # Without this the deploy chain breaks: build image → push ECR → Ansible pull → run
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:TagResource",
      "ecr:PutLifecyclePolicy",
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.project}-*"
    ]
  }
}

resource "aws_iam_policy" "github_actions" {
  name        = "${var.project}-${var.environment}-github-actions-policy"
  description = "Scoped permissions for GitHub Actions Terraform CI/CD"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

# ─────────────────────────────────────────────
# EC2 Instance Profile
# What app servers are allowed to do — no more
# CIS: no AdministratorAccess on EC2
# ─────────────────────────────────────────────
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project}-${var.environment}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-ec2-role"
  })
}

# SSM Session Manager — allows console access without open SSH port
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent — send metrics and logs
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ECR read — pull Docker images (app-deploy Ansible role)
resource "aws_iam_role_policy_attachment" "ec2_ecr" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# S3 access — scoped to project bucket only
data "aws_iam_policy_document" "ec2_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_policy" "ec2_s3" {
  name   = "${var.project}-${var.environment}-ec2-s3-policy"
  policy = data.aws_iam_policy_document.ec2_s3.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "ec2_s3" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_s3.arn
}

# SSM Parameter Store read — app reads its own secrets
data "aws_iam_policy_document" "ec2_ssm_params" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project}/*"
    ]
  }
}

resource "aws_iam_policy" "ec2_ssm_params" {
  name   = "${var.project}-${var.environment}-ec2-ssm-params-policy"
  policy = data.aws_iam_policy_document.ec2_ssm_params.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_params" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_ssm_params.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.environment}-ec2-instance-profile"
  role = aws_iam_role.ec2.name

  tags = var.tags
}
