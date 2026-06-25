# ─────────────────────────────────────────────
# SNS Topic — alarm notifications
# ─────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${var.project}-${var.environment}-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
  # Note: AWS sends a confirmation email — you must click confirm before alerts fire
}

# ─────────────────────────────────────────────
# Log Groups
# ─────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project}/${var.environment}/app"
  retention_in_days = 14 # Cost control — 14 days is enough for sprint evidence

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-app-logs"
  })
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/${var.project}/${var.environment}/nginx"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "system" {
  name              = "/${var.project}/${var.environment}/system"
  retention_in_days = 7

  tags = var.tags
}

# ─────────────────────────────────────────────
# EC2 / ASG Alarms
# ─────────────────────────────────────────────

# High CPU — triggers scale-up
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project}-${var.environment}-cpu-high"
  alarm_description   = "ASG average CPU above 70% for 2 consecutive periods"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  alarm_actions = [
    aws_sns_topic.alerts.arn,
    var.scale_up_policy_arn
  ]

  tags = var.tags
}

# Low CPU — triggers scale-down
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project}-${var.environment}-cpu-low"
  alarm_description   = "ASG average CPU below 20% — scale down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 20

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  alarm_actions = [var.scale_down_policy_arn]

  tags = var.tags
}

# ─────────────────────────────────────────────
# RDS Alarms
# ─────────────────────────────────────────────

# High DB connections
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.project}-${var.environment}-rds-connections-high"
  alarm_description   = "RDS connection count above 80"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.tags
}

# Low free storage
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.project}-${var.environment}-rds-storage-low"
  alarm_description   = "RDS free storage below 5GB"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5GB in bytes

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.tags
}

# High RDS CPU
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project}-${var.environment}-rds-cpu-high"
  alarm_description   = "RDS CPU above 80%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.tags
}

# ─────────────────────────────────────────────
# ALB Alarms
# ─────────────────────────────────────────────

# 5XX errors from targets
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project}-${var.environment}-alb-5xx"
  alarm_description   = "ALB 5XX error rate above 10 per minute"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.tags
}

# Unhealthy host count
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project}-${var.environment}-unhealthy-hosts"
  alarm_description   = "One or more unhealthy targets in ALB target group"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.tags
}

# ─────────────────────────────────────────────
# CloudWatch Dashboard
# Single-pane view of all key metrics
# ─────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EC2 CPU Utilization"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "RDS Connections + CPU"
          period = 60
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_identifier],
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_identifier]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count"
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB 5XX Errors + Unhealthy Hosts"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix]
          ]
          view = "timeSeries"
        }
      }
    ]
  })
}

# ─────────────────────────────────────────────
# CloudWatch Agent Config
# Stored in SSM — agent reads this on start
# Memory + disk metrics (not available by default in CloudWatch)
# ─────────────────────────────────────────────
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name        = "/AmazonCloudWatch-linux-${var.project}-${var.environment}"
  description = "CloudWatch agent configuration for ${var.project} ${var.environment}"
  type        = "String"

  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }
    metrics = {
      metrics_collected = {
        cpu = {
          measurement                 = ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"]
          metrics_collection_interval = 60
          totalcpu                    = true
        }
        disk = {
          measurement                 = ["used_percent", "inodes_free"]
          metrics_collection_interval = 60
          resources                   = ["*"]
        }
        mem = {
          measurement                 = ["mem_used_percent"]
          metrics_collection_interval = 60
        }
      }
      append_dimensions = {
        AutoScalingGroupName = "$${aws:AutoScalingGroupName}"
        ImageId              = "$${aws:ImageId}"
        InstanceId           = "$${aws:InstanceId}"
        InstanceType         = "$${aws:InstanceType}"
      }
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path         = "/var/log/nginx/access.log"
              log_group_name    = "/${var.project}/${var.environment}/nginx"
              log_stream_name   = "{instance_id}/access"
              retention_in_days = 14
            },
            {
              file_path         = "/var/log/nginx/error.log"
              log_group_name    = "/${var.project}/${var.environment}/nginx"
              log_stream_name   = "{instance_id}/error"
              retention_in_days = 14
            },
            {
              file_path         = "/opt/app/logs/app.log"
              log_group_name    = "/${var.project}/${var.environment}/app"
              log_stream_name   = "{instance_id}/app"
              retention_in_days = 14
            }
          ]
        }
      }
    }
  })

  tags = var.tags
}
