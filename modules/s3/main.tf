# ─────────────────────────────────────────────
# App Assets Bucket
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "app" {
  bucket = "${var.project}-${var.environment}-app-assets"

  # Prevent accidental delete of non-empty bucket during terraform destroy
  force_destroy = true # Set false in prod — true here for sprint teardown ease

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-app-assets"
  })
}

# Block all public access — CIS requirement
resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning — enables recovery of overwritten/deleted objects
resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest — AES-256 (SSE-S3, no extra cost)
resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy — move old versions to cheaper storage, then expire
resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ─────────────────────────────────────────────
# VPC Flow Logs Bucket (separate from app assets)
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "flow_logs" {
  bucket        = "${var.project}-${var.environment}-flow-logs"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-flow-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  bucket                  = aws_s3_bucket.flow_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Flow logs bucket policy — allow VPC Flow Logs service to write
resource "aws_s3_bucket_policy" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_bucket.json
}

data "aws_iam_policy_document" "flow_logs_bucket" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.flow_logs.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.flow_logs.arn]
  }
}

# Lifecycle — expire flow logs after 30 days (cost control)
resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    id     = "expire-flow-logs"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}
