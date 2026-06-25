# ─────────────────────────────────────────────
# Application Load Balancer
# HTTP only — domain + ACM cert pattern documented below
# ─────────────────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = var.public_subnet_ids

  # Access logs (optional — costs ~$0.008/GB, disabled for sprint)
  # enable_access_logs = true
  # access_logs {
  #   bucket  = var.access_logs_bucket
  #   prefix  = "alb"
  #   enabled = true
  # }

  enable_deletion_protection = false # Set true in prod

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-alb"
  })
}

# ─────────────────────────────────────────────
# Target Group
# ALB forwards to EC2 instances on this group
# ─────────────────────────────────────────────
resource "aws_lb_target_group" "app" {
  name        = "${var.project}-${var.environment}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  # Drain connections gracefully before deregistering
  deregistration_delay = 30

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-tg"
  })
}

# ─────────────────────────────────────────────
# Listener — HTTP:80
# For HTTPS: replace with port 443, protocol HTTPS, add certificate_arn
# HTTPS pattern (commented out — requires ACM cert + domain):
#
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = var.acm_certificate_arn
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app.arn
#   }
# }
#
# resource "aws_lb_listener" "http_redirect" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "80"
#   protocol          = "HTTP"
#   default_action {
#     type = "redirect"
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }
# ─────────────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-listener-http"
  })
}
