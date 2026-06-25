# ─────────────────────────────────────────────
# RDS Subnet Group
# Must span 2+ AZs even for single-AZ deployment
# ─────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name        = "${var.project}-${var.environment}-db-subnet-group"
  description = "Private subnets for RDS — no public access"
  subnet_ids  = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  })
}

# ─────────────────────────────────────────────
# RDS Parameter Group
# Custom PostgreSQL settings
# ─────────────────────────────────────────────
resource "aws_db_parameter_group" "main" {
  name        = "${var.project}-${var.environment}-pg-params"
  family      = "postgres15"
  description = "Custom parameters for ${var.project} ${var.environment}"

  # Enable query logging — useful for debugging, required for some CIS checks
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  # Log queries slower than 1 second
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-pg-params"
  })
}

# ─────────────────────────────────────────────
# RDS Instance
# CIS: private subnet, encryption at rest, automated backups
# Cost note: db.t3.micro = ~$0.017/hr. 20GB gp2 = ~$0.115/GB-month
# Sprint: 2 days = ~$0.82 compute + ~$0.15 storage = ~$1 total
# ─────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}-postgres"

  # Engine
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.instance_class

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = 100 # Auto-scaling storage ceiling
  storage_type          = "gp2"
  storage_encrypted     = true # CIS: encryption at rest required

  # Credentials — never in source code
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network — private subnet only, no public endpoint
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.sg_rds_id]
  publicly_accessible    = false # CIS: no public RDS

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Backups
  backup_retention_period = 7             # 7 days of automated backups
  backup_window           = "03:00-04:00" # UTC, low-traffic window
  maintenance_window      = "sun:04:00-sun:05:00"

  # Monitoring
  monitoring_interval = 60 # Enhanced monitoring — 60 second intervals
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Multi-AZ: documented but disabled for cost
  # multi_az = true  # Enable in production — doubles the cost
  multi_az = false

  # Deletion protection: off for sprint (on for prod)
  deletion_protection = false
  skip_final_snapshot = true # Set false in prod and name the snapshot

  # Performance Insights (free for db.t3.micro, 7-day retention)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-postgres"
  })
}

# ─────────────────────────────────────────────
# RDS Enhanced Monitoring Role
# Allows RDS to push OS metrics to CloudWatch
# ─────────────────────────────────────────────
data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "${var.project}-${var.environment}-rds-monitoring-role"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
