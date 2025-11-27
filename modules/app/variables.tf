
variable "env_name" {}
variable "vpc_id" {}
variable "alb_sg_id" {}
variable "ami_id" {}
variable "instance_type" {}
variable "instance_profile_name" {}
variable "ssh_key_name" {}
variable "private_subnets" { type = list(string) }
variable "target_group_arn" {}
variable "app_repo" {}
variable "datadog_api_key" { sensitive = true }
variable "datadog_site" {}
variable "gremlin_team_id" { sensitive = true }
variable "gremlin_secret" { sensitive = true }
variable "test_data_bucket" {}
