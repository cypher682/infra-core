# ─────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # Required for SSM Session Manager + RDS hostname resolution

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

# ─────────────────────────────────────────────
# Internet Gateway
# ─────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

# ─────────────────────────────────────────────
# Public Subnets (ALB + NAT GW)
# ─────────────────────────────────────────────
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Instances in public subnet get public IPs (ALB, NAT)

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-public-${count.index + 1}"
    Tier = "public"
  })
}

# ─────────────────────────────────────────────
# Private Subnets (EC2 app servers + RDS)
# ─────────────────────────────────────────────
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  # No map_public_ip_on_launch — private subnet, outbound via NAT only

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-private-${count.index + 1}"
    Tier = "private"
  })
}

# ─────────────────────────────────────────────
# NAT Gateway (single, in first public subnet)
# Cost note: NAT GW is ~$0.045/hr + $0.045/GB data
# Single NAT is sufficient for dev/staging — HA would use one per AZ
# ─────────────────────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Always in first public subnet

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat-gw"
  })

  depends_on = [aws_internet_gateway.main]
}

# ─────────────────────────────────────────────
# Route Tables
# ─────────────────────────────────────────────

# Public route table — default route to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table — default route to NAT GW
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-rt-private"
  })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ─────────────────────────────────────────────
# Security Groups
# CIS principle: least privilege — deny all, open only what is needed
# ─────────────────────────────────────────────

# ALB — accepts HTTP from internet
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-sg-alb"
  description = "ALB: accept HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound to app servers"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-sg-alb"
  })
}

# App servers — accept traffic only from ALB
resource "aws_security_group" "app" {
  name        = "${var.project}-${var.environment}-sg-app"
  description = "App servers: accept traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound (NAT GW for updates, SSM, ECR)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-sg-app"
  })
}

# RDS — accept connections from app servers only
resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-sg-rds"
  description = "RDS: accept PostgreSQL from app servers only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from app servers only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # No egress needed — RDS does not initiate outbound connections
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-sg-rds"
  })
}


# ─────────────────────────────────────────────
# VPC Flow Logs → S3
# CIS: network traffic logging required
# ─────────────────────────────────────────────
resource "aws_flow_log" "main" {
  log_destination      = var.flow_log_bucket_arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-flow-logs"
  })
}
