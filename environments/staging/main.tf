terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  project     = "infra-core"
  environment = "staging"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = "cypher682"
  }
}

module "s3" {
  source      = "../../modules/s3"
  project     = local.project
  environment = local.environment
  tags        = local.common_tags
}

module "ecr" {
  source          = "../../modules/ecr"
  repository_name = "${local.project}-${local.environment}-app-repo"
  tags            = local.common_tags
}

module "iam" {
  source         = "../../modules/iam"
  project        = local.project
  environment    = local.environment
  github_org     = var.github_org
  github_repo    = var.github_repo
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region
  s3_bucket_arn  = module.s3.app_bucket_arn
  tags           = local.common_tags
}

module "vpc" {
  source      = "../../modules/vpc"
  project     = local.project
  environment = local.environment

  # Different CIDRs from dev — avoids overlap if both VPCs exist at same time
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]

  flow_log_bucket_arn = module.s3.flow_logs_bucket_arn
  tags                = local.common_tags
}

module "rds" {
  source      = "../../modules/rds"
  project     = local.project
  environment = local.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_rds_id          = module.vpc.sg_rds_id

  db_name        = "appdb"
  db_username    = var.db_username
  db_password    = var.db_password
  instance_class = "db.t3.micro"

  tags = local.common_tags
}

module "alb" {
  source      = "../../modules/alb"
  project     = local.project
  environment = local.environment

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  sg_alb_id         = module.vpc.sg_alb_id

  health_check_path = "/health"
  target_port       = 80
  tags              = local.common_tags
}

module "ec2_asg" {
  source      = "../../modules/ec2-asg"
  project     = local.project
  environment = local.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_app_id          = module.vpc.sg_app_id
  target_group_arn   = module.alb.target_group_arn

  ec2_instance_profile_name = module.iam.ec2_instance_profile_name
  ssm_parameter_namespace   = "/${local.project}/${local.environment}"

  instance_type        = "t3.micro"
  asg_min_size         = 1
  asg_max_size         = 2
  asg_desired_capacity = 1

  tags = local.common_tags
}

module "ssm" {
  source      = "../../modules/ssm"
  project     = local.project
  environment = local.environment

  db_password = var.db_password
  db_username = var.db_username
  db_host     = module.rds.db_host
  db_name     = "appdb"

  tags = local.common_tags
}

module "cloudwatch" {
  source      = "../../modules/cloudwatch"
  project     = local.project
  environment = local.environment

  asg_name                = module.ec2_asg.asg_name
  db_identifier           = module.rds.db_identifier
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  scale_up_policy_arn   = module.ec2_asg.scale_up_policy_arn
  scale_down_policy_arn = module.ec2_asg.scale_down_policy_arn

  alert_email = var.alert_email
  tags        = local.common_tags
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

