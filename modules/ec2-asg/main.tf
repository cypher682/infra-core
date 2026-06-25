# ─────────────────────────────────────────────
# Latest Amazon Linux 2023 AMI
# Using data source — always gets current AMI, no hardcoded IDs
# ─────────────────────────────────────────────
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─────────────────────────────────────────────
# Launch Template
# User data bootstraps the instance on first boot
# ─────────────────────────────────────────────
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-${var.environment}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  # Instance profile — grants EC2 permissions to SSM, S3, CloudWatch
  iam_instance_profile {
    name = var.ec2_instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false # Private subnet — no direct public IP
    security_groups             = [var.sg_app_id]
    delete_on_termination       = true
  }

  # EBS root volume — encrypted at rest
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true # CIS: disk encryption required
      delete_on_termination = true
    }
  }

  # User data — runs on first boot
  # Installs: Docker, CloudWatch agent, nginx
  # App startup is handled by Ansible after provisioning
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project       = var.project
    environment   = var.environment
    ssm_namespace = var.ssm_parameter_namespace
  }))

  # Require IMDSv2 — CIS: prevents SSRF attacks against metadata service
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true # Detailed CloudWatch monitoring (1-minute intervals)
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.project}-${var.environment}-app-server"
      Role = "app"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.project}-${var.environment}-app-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-launch-template"
  })

  lifecycle {
    create_before_destroy = true # Zero-downtime launch template updates
  }
}

# ─────────────────────────────────────────────
# Auto Scaling Group
# ─────────────────────────────────────────────
resource "aws_autoscaling_group" "app" {
  name                = "${var.project}-${var.environment}-asg"
  vpc_zone_identifier = var.private_subnet_ids

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  # Health check — use ELB health check (more accurate than EC2 status)
  health_check_type         = "ELB"
  health_check_grace_period = 300 # 5 min — give instance time to boot + register

  # Attach to ALB target group
  target_group_arns = [var.target_group_arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Instance refresh — rolling update when launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  # Propagate tags to EC2 instances
  dynamic "tag" {
    for_each = merge(var.tags, {
      Name        = "${var.project}-${var.environment}-app-server"
      Environment = var.environment
      Project     = var.project
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity] # Ignore changes made by scaling policies
  }
}

# ─────────────────────────────────────────────
# Auto Scaling Policy — CPU-based
# Scale up when avg CPU > 70% for 2 consecutive periods
# ─────────────────────────────────────────────
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project}-${var.environment}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project}-${var.environment}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

