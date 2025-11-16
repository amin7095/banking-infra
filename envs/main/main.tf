
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws" version = "~> 5.0" }
  }
}

provider "aws" { region = var.aws_region }

module "network" {
  source = "../../modules/network"
  name   = var.env_name
}

module "rds_mysql" {
  source              = "../../modules/rds_mysql"
  name                = var.env_name
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
}

module "alb" {
  source            = "../../modules/alb"
  name              = var.env_name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
}

# Render user_data with secrets from TFC variables
data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")

  vars = {
    app_repo        = var.app_repo
    payment_mode    = var.payment_mode
    env_name        = var.env_name
    datadog_api_key = var.datadog_api_key
    datadog_site    = var.datadog_site
    gremlin_team_id = var.gremlin_team_id
    gremlin_secret  = var.gremlin_secret
    db_host         = module.rds_mysql.endpoint
    db_username     = var.db_username
    db_password     = var.db_password
  }
}

module "app_asg" {
  source             = "../../modules/app_asg"
  name               = var.env_name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  alb_tg_arn         = module.alb.target_group_arn
  instance_type      = var.instance_type
  ssh_public_key     = var.ssh_public_key
  user_data          = data.template_file.user_data.rendered
}

# Allow ALB to reach app (port 8080) via SG rule module
module "alb_to_app" {
  source    = "../../modules/alb/sg_link"
  alb_sg_id = module.alb.sg_id
  app_sg_id = module.app_asg.sg_id
  app_port  = 8080
}

# Allow app SG to reach RDS SG on 3306
resource "aws_security_group_rule" "app_to_rds" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = module.rds_mysql.sg_id
  source_security_group_id = module.app_asg.sg_id
}

module "dynamodb" {
  source              = "../../modules/dynamodb"
  dynamodb_table_name = var.dynamodb_table_name
}

# Load all WireMock mappings from folder and pass to module
locals {
  mapping_files = fileset("${path.module}/wiremock_mappings", "*.json")
  mappings      = { for f in local.mapping_files : basename(f) => file("${path.module}/wiremock_mappings/${f}") }
}

module "wiremock" {
  source            = "../../modules/wiremock"
  name              = var.env_name
  vpc_id            = module.network.vpc_id
  private_subnet_id = module.network.private_subnet_ids[0]
  app_sg_id         = module.app_asg.sg_id
  mappings          = local.mappings
}
