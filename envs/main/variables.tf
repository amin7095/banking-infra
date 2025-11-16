
variable "aws_region"          { type = string }
variable "env_name"            { type = string }
variable "instance_type" {
  type    = string
  default = "t3.medium"
}
variable "app_repo"            { type = string }
variable "payment_mode" {
  type    = string
  default = "wiremock"
}
variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "dynamodb_table_name" { type = string  default = "test-data" }
variable "ssh_public_key"      { type = string }

variable "datadog_api_key" {
  type      = string
  sensitive = true
}

variable "datadog_site"        { type = string  default = "datadoghq.eu" }

variable "gremlin_team_id" {
  type      = string
  sensitive = true
}


variable "gremlin_secret" {
  type      = string
  sensitive = true
}

